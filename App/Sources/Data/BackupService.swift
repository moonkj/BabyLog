// BackupService.swift
// BabyLog — 전체 데이터 백업/복원 (사진·영상 포함 단일 파일)
//
// 아기 사진은 이 앱의 가장 중요한 자산이다. 앱 삭제·기기 변경에도 데이터를 지키기 위한
// 사용자 주도 백업: 상태(JSON) + 모든 사진/영상을 단일 .babylogbackup로 묶어
// 파일 앱/iCloud Drive/AirDrop으로 저장·이전한다. 서버 불필요(무료).
//
// ⚠️ 메모리: 사진을 전부 RAM에 올리지 않는다. FileHandle 청크 스트리밍(파일→파일)으로
//    피크 메모리를 수 MB로 유지 → 사진 수 GB 사용자도 워치독에 죽지 않는다.
//    포맷: [magic "BLBK"][ver u32][stateLen u64][state JSON][count u32]
//          반복{ [nameLen u32][name][dataLen u64][raw bytes] }  (모두 little-endian)
//    구버전(.babylogbackup = 바이너리 plist) 백업은 자동 감지해 폴백 복원한다.

import Foundation

/// 레거시(v1) 단일 백업 아카이브 — 구포맷 폴백 복원 전용.
struct BackupArchive: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var state: PersistableState
    var photos: [String: Data]   // 파일명 → 원본 바이트
}

enum BackupService {
    static let fileExtension = "babylogbackup"

    private static let magic = Data("BLBK".utf8)      // 4바이트 식별자
    private static let formatVersion: UInt32 = 2
    private static let chunkSize = 1 << 20            // 1MB 청크
    private static let maxStateBytes = 256_000_000    // 방어적 상한(상태 JSON)
    private static let maxNameBytes = 1024

    private enum BackupError: Error { case malformed }

    private static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private static func jsonEncoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private static func jsonDecoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    // MARK: - Backup (스트리밍)

    /// 백업 파일을 임시 경로에 생성하고 URL 반환. 상태 스냅샷만 메인에서, 파일 I/O는 백그라운드.
    @MainActor
    static func makeArchive(_ store: AppStore) async -> URL? {
        let state = store.snapshot()                              // 메인에서 스냅샷
        guard let stateData = try? jsonEncoder().encode(state) else { return nil }
        let photoURLs = PhotoStore.allPhotoFileURLs()             // URL만(데이터 미로딩)
        return await Task.detached(priority: .userInitiated) {
            writeArchive(stateData: stateData, photoURLs: photoURLs)
        }.value
    }

    nonisolated private static func writeArchive(stateData: Data, photoURLs: [URL]) -> URL? {
        let fm = FileManager.default
        let url = fm.temporaryDirectory
            .appendingPathComponent("BabyLog-Backup-\(stamp()).\(fileExtension)")
        fm.createFile(atPath: url.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: url) else { return nil }
        var ok = true
        do {
            // 파일 크기는 속성으로만 읽는다(데이터 미로딩).
            let entries: [(url: URL, name: Data, size: UInt64)] = photoURLs.compactMap { p in
                guard let attrs = try? fm.attributesOfItem(atPath: p.path),
                      let n = attrs[.size] as? NSNumber else { return nil }
                return (p, Data(p.lastPathComponent.utf8), n.uint64Value)
            }
            try out.write(contentsOf: magic)
            try out.write(contentsOf: u32(formatVersion))
            try out.write(contentsOf: u64(UInt64(stateData.count)))
            try out.write(contentsOf: stateData)
            try out.write(contentsOf: u32(UInt32(entries.count)))
            for e in entries {
                try out.write(contentsOf: u32(UInt32(e.name.count)))
                try out.write(contentsOf: e.name)
                try out.write(contentsOf: u64(e.size))
                try streamFile(e.url, to: out, declared: e.size)
            }
        } catch { ok = false }
        try? out.close()
        if !ok { try? fm.removeItem(at: url); return nil }
        return url
    }

    /// 원본 파일을 청크로 읽어 out에 그대로 흘려보낸다(declared 바이트 보장 — 짧으면 0패딩).
    nonisolated private static func streamFile(_ src: URL, to out: FileHandle, declared: UInt64) throws {
        let inH = try FileHandle(forReadingFrom: src)
        defer { try? inH.close() }
        var written: UInt64 = 0
        while written < declared {
            let want = Int(min(UInt64(chunkSize), declared - written))
            guard let chunk = try inH.read(upToCount: want), !chunk.isEmpty else { break }
            try out.write(contentsOf: chunk)
            written += UInt64(chunk.count)
        }
        // 백업 도중 파일이 짧아진 희귀 케이스 — 프레이밍 정렬 유지 위해 0패딩
        var pad = declared - written
        while pad > 0 {
            let n = Int(min(UInt64(chunkSize), pad))
            try out.write(contentsOf: Data(count: n))
            pad -= UInt64(n)
        }
    }

    // MARK: - Restore (스트리밍)

    /// 백업 파일에서 복원. 파일 파싱·사진 기록은 백그라운드, 상태 적용만 메인.
    static func restore(from url: URL, into store: AppStore) async -> Bool {
        let state = await Task.detached(priority: .userInitiated) {
            readArchive(from: url)
        }.value
        guard let state else { return false }
        await MainActor.run { store.restore(state) }
        return true
    }

    /// 스트리밍 복원: 사진은 디스크로 곧장 기록, 상태(PersistableState)만 반환. 실패 시 nil.
    nonisolated private static func readArchive(from url: URL) -> PersistableState? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let inH = try? FileHandle(forReadingFrom: url) else { return nil }
        guard let head = try? readExactly(inH, 4) else { try? inH.close(); return nil }
        if head != magic {
            try? inH.close()
            return restoreLegacy(url)             // 구포맷(바이너리 plist) 폴백
        }
        defer { try? inH.close() }
        do {
            _ = try readExactly(inH, 4)           // version (단일 포맷 — 무시)
            let stateLen = try readU64(inH)
            guard stateLen <= UInt64(maxStateBytes) else { throw BackupError.malformed }
            let stateData = try readExactly(inH, Int(stateLen))
            let state = try jsonDecoder().decode(PersistableState.self, from: stateData)
            let count = try readU32(inH)
            for _ in 0..<count {
                let nameLen = try readU32(inH)
                guard nameLen <= UInt32(maxNameBytes) else { throw BackupError.malformed }
                let name = String(decoding: try readExactly(inH, Int(nameLen)), as: UTF8.self)
                let size = try readU64(inH)
                if let dest = PhotoStore.safeRestoreURL(for: name) {
                    try streamOut(inH, to: dest, length: size)
                } else {
                    try discard(inH, length: size)   // 안전치 않은 이름 — 바이트만 소비(정렬 유지)
                }
            }
            return state
        } catch { return nil }
    }

    /// 입력에서 length 바이트를 dest 파일로 청크 기록(덮어쓰기).
    nonisolated private static func streamOut(_ inH: FileHandle, to dest: URL, length: UInt64) throws {
        let fm = FileManager.default
        fm.createFile(atPath: dest.path, contents: nil)      // 생성/절단
        let outH = try FileHandle(forWritingTo: dest)
        defer { try? outH.close() }
        var remaining = length
        while remaining > 0 {
            let want = Int(min(UInt64(chunkSize), remaining))
            guard let chunk = try inH.read(upToCount: want), !chunk.isEmpty else { throw BackupError.malformed }
            try outH.write(contentsOf: chunk)
            remaining -= UInt64(chunk.count)
        }
    }

    /// 입력에서 length 바이트를 읽어 버린다(기록하지 않음).
    nonisolated private static func discard(_ inH: FileHandle, length: UInt64) throws {
        var remaining = length
        while remaining > 0 {
            let want = Int(min(UInt64(chunkSize), remaining))
            guard let chunk = try inH.read(upToCount: want), !chunk.isEmpty else { throw BackupError.malformed }
            remaining -= UInt64(chunk.count)
        }
    }

    /// 구포맷(v1, 바이너리 plist) 폴백 — 통째 로드(구 백업은 작다고 가정).
    nonisolated private static func restoreLegacy(_ url: URL) -> PersistableState? {
        guard let data = try? Data(contentsOf: url),
              let archive = try? PropertyListDecoder().decode(BackupArchive.self, from: data) else {
            return nil
        }
        PhotoStore.restorePhotos(archive.photos)
        return archive.state
    }

    // MARK: - 바이트 헬퍼

    nonisolated private static func readExactly(_ h: FileHandle, _ n: Int) throws -> Data {
        if n == 0 { return Data() }
        var out = Data(); out.reserveCapacity(n)
        while out.count < n {
            guard let chunk = try h.read(upToCount: n - out.count), !chunk.isEmpty else { break }
            out.append(chunk)
        }
        guard out.count == n else { throw BackupError.malformed }
        return out
    }
    nonisolated private static func readU32(_ h: FileHandle) throws -> UInt32 {
        try readExactly(h, 4).withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
    nonisolated private static func readU64(_ h: FileHandle) throws -> UInt64 {
        try readExactly(h, 8).withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self)) }
    }
    nonisolated private static func u32(_ v: UInt32) -> Data {
        var le = v.littleEndian; return withUnsafeBytes(of: &le) { Data($0) }
    }
    nonisolated private static func u64(_ v: UInt64) -> Data {
        var le = v.littleEndian; return withUnsafeBytes(of: &le) { Data($0) }
    }
}
