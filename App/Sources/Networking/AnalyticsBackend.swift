// AnalyticsBackend.swift
// BabyLog · Networking — 익명 접속 통계(집계 전용). 개인·아동 정보 없음.
// 하루 1회 ownerID+KST날짜+버전만 서버에 기록(bl_active_ping RPC). 관리자 대시보드 집계용.

import Foundation
import UIKit

enum AnalyticsBackend {
    /// 앱 포그라운드 진입 시 1회 호출. 같은 날(KST) 중복은 클라에서 skip(서버도 unique 이중 방지).
    static func ping() async {
        guard SupabaseConfig.isConfigured else { return }
        // 익명 이용통계 옵트아웃(PIPA 거부권) — 설정에서 끄면 전송 안 함.
        if UserDefaults.standard.bool(forKey: "bl_analytics_off") { return }
        let today = kstDayString()
        if UserDefaults.standard.string(forKey: "bl_last_ping_day") == today { return }
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/rest/v1/rpc/bl_active_ping") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 비로그인 식별(서버 bl_owner_id)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let appV = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let osV = await MainActor.run { "iOS \(UIDevice.current.systemVersion)" }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_app": appV, "p_os": osV])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
        UserDefaults.standard.set(today, forKey: "bl_last_ping_day")
    }

    private static func authBearer() async -> String {
        if let t = await AuthStore.shared.validAccessToken() { return t }
        return SupabaseConfig.anonKey ?? ""
    }

    /// KST 기준 오늘 날짜 키(yyyy-MM-dd) — 자정 경계를 서버 집계(Asia/Seoul)와 맞춤.
    private static func kstDayString() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
