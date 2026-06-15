// StoreManager.swift
// BabyLog · StoreKit 2 Pro 구독 — 상품 로드·구매·복원·엔타이틀먼트 판정.
//
// 클라이언트 게이트(가족공유·마켓 다중판매 등)는 AppStore.isPro를 읽는데, 그 값은 여기
// 엔타이틀먼트(Transaction.currentEntitlements)로 갱신된다(BabyLogApp 브리지).
// 서버 게이트(가족 피드 RLS·media-upload-url)는 verify-subscription Edge가 bl_profile.is_pro를
// 권위적으로 설정한다 — 구매 직후·복원·앱 시작 시 syncServer()로 호출한다.
//
// ⚠️ 실제 과금은 App Store Connect에 아래 ProductID로 자동구독 상품을 등록해야 동작한다.
//    로컬 테스트는 Products.storekit 설정 파일을 스킴 Run > Options에 지정.

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// App Store Connect 자동구독 상품 ID(등록 값과 정확히 일치해야 함).
    enum ProductID {
        static let monthly = "com.vibelab.babylog.pro.monthly"
        static let yearly  = "com.vibelab.babylog.pro.yearly"
        static let all: [String] = [monthly, yearly]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false   // 실제 엔타이틀먼트(StoreKit)
    @Published private(set) var purchasing = false
    @Published private(set) var loaded = false         // 상품 로드 시도 완료(빈 배열이면 미등록/오프라인)
    @Published var lastError: String?

    /// 엔타이틀먼트 변화 콜백 — AppStore.isPro 브리지에 사용.
    var onEntitlementChange: ((Bool) -> Void)?

    private var updatesTask: Task<Void, Never>?

    private init() {}

    var monthly: Product? { products.first { $0.id == ProductID.monthly } }
    var yearly: Product?  { products.first { $0.id == ProductID.yearly } }

    /// 앱 시작 시 1회 — 거래 업데이트 구독 시작 + 엔타이틀먼트/서버/상품 동기화.
    func start() {
        if updatesTask == nil { updatesTask = listenForTransactions() }
        Task {
            await syncNow()          // 엔타이틀먼트 + 서버 등급(is_pro) 동기화
            await loadProducts()
        }
    }

    /// 엔타이틀먼트 재판정 + 서버 등급 동기화 — 시작·포그라운드 공통(외부 구독 변경 반영).
    func syncNow() async {
        await refreshEntitlement()   // 오프라인에서도 StoreKit 로컬 캐시로 동작
        await syncServer()           // 비로그인 시 내부에서 조용히 skip
    }

    func loadProducts() async {
        do {
            let items = try await Product.products(for: ProductID.all)
            products = items.sorted { $0.price < $1.price }
        } catch {
            lastError = "상품 정보를 불러오지 못했어요."
        }
        loaded = true
    }

    /// 구매 — 거래를 구매자 uid에 묶어(appAccountToken) 서버 검증이 소유자를 대조하게 한다.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchasing = true
        defer { purchasing = false }
        lastError = nil
        var options: Set<Product.PurchaseOption> = []
        if let uid = AuthStore.shared.userId, let token = UUID(uuidString: uid) {
            options.insert(.appAccountToken(token))
        }
        do {
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                guard let txn = verified(verification) else {
                    lastError = "구매 확인에 실패했어요. 다시 시도해 주세요."
                    return false
                }
                await txn.finish()
                await refreshEntitlement()
                await syncServer()
                return isSubscribed
            case .userCancelled:
                return false
            case .pending:
                lastError = "구매가 대기 중이에요(승인이 필요할 수 있어요)."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "구매를 완료하지 못했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    /// 구매 복원 — 기기 변경·재설치 후. App Store 요건.
    func restore() async {
        purchasing = true
        defer { purchasing = false }
        do { try await StoreKit.AppStore.sync() } catch { /* 사용자 취소/네트워크 — 무음 */ }
        await refreshEntitlement()
        await syncServer()
        if !isSubscribed { lastError = "복원할 구독이 없어요." }
    }

    /// 현재 유효한 구독 엔타이틀먼트가 있는지 재판정(앱 게이트의 근거).
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let txn = verified(result) else { continue }
            guard ProductID.all.contains(txn.productID), txn.revocationDate == nil else { continue }
            if let exp = txn.expirationDate { if exp > Date() { active = true } }
            else { active = true }   // 만료 없는 엔타이틀먼트(비구독형) 안전망
        }
        if active != isSubscribed { isSubscribed = active }
        onEntitlementChange?(active)
    }

    /// 거래 업데이트(갱신·환불·다른 기기 구매) 실시간 반영.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let txn = await self.verifiedValue(update) { await txn.finish() }
                await self.refreshEntitlement()
                await self.syncServer()
            }
        }
    }

    private nonisolated func verifiedValue(_ result: VerificationResult<Transaction>) -> Transaction? {
        if case .verified(let txn) = result { return txn }
        return nil
    }
    private func verified(_ result: VerificationResult<Transaction>) -> Transaction? {
        if case .verified(let txn) = result { return txn }
        return nil
    }

    /// 서버 권위 갱신 — 현재 구독 거래 id를 verify-subscription Edge로 보내 bl_profile.is_pro 설정.
    /// (서버 게이트: 가족 피드 RLS·media-upload-url. 클라 게이트와 별개로 서버가 최종 판정.)
    private func syncServer() async {
        guard SupabaseConfig.isConfigured,
              let token = await AuthStore.shared.validAccessToken(),
              let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/verify-subscription") else { return }
        // 현재 엔타이틀먼트의 거래 id(가장 최근) 추출.
        var txnId: UInt64?
        for await result in Transaction.currentEntitlements {
            guard let txn = verified(result), ProductID.all.contains(txn.productID) else { continue }
            txnId = txn.id
        }
        guard let id = txnId else { return }   // 구독 없음 — 서버 만료 처리는 App Store 알림 경로(추후)
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["transactionId": String(id)])
        _ = try? await URLSession.shared.data(for: req)
    }
}
