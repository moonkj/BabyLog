import Foundation
import Combine

// BlockStore — 사용자 차단(숨기기). App Store 심사 가이드라인 1.2(UGC)는 신고 외에
// '악성 사용자 차단' 수단을 요구한다. 차단한 작성자(authorId)의 메시지·댓글을 즉시 숨긴다.
//
// 클라이언트 측 숨김(로컬 UserDefaults). 서버 양방향 차단(bl_block 테이블)은 후속 확장 가능.
// 식별자는 작성자 식별자(authorId = auth.uid 또는 기기ID). 닉네임은 중복 가능하므로 쓰지 않는다.
@MainActor
final class BlockStore: ObservableObject {
    static let shared = BlockStore()

    @Published private(set) var blocked: Set<String>
    private let key = "bl_blocked_authors"

    private init() {
        blocked = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func isBlocked(_ id: String?) -> Bool {
        guard let id, !id.isEmpty else { return false }
        return blocked.contains(id)
    }

    func block(_ id: String?) {
        guard let id, !id.isEmpty else { return }
        blocked.insert(id)
        persist()
    }

    func unblock(_ id: String) {
        blocked.remove(id)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(blocked), forKey: key)
    }
}
