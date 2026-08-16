import Foundation

@MainActor
final class PaywallViewModel {

    struct Snapshot: Equatable {
        let products: [SublyProduct]
        let selectedProductID: String?
        let isPurchasing: Bool
        let isRestoring: Bool
        let isCurrentlyPlus: Bool
    }

    private let storeKitService: StoreKitService

    private var products: [SublyProduct] = []
    private var selectedProductID: String?
    private var isPurchasing = false
    private var isRestoring = false
    private var entitlement: SublyEntitlement = .free

    private(set) var state: ViewState<Snapshot> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Snapshot>) -> Void)?
    var onErrorMessage: ((String) -> Void)?
    var onPurchaseSucceeded: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(storeKitService: StoreKitService) {
        self.storeKitService = storeKitService
    }

    func load() {
        state = .loading
        Task { [weak self] in
            guard let self else { return }
            entitlement = await storeKitService.currentEntitlement()
            do {
                products = try await storeKitService.products()
                selectedProductID = preferredSelection(in: products)
                publishSnapshot()
            } catch let error as UserFacingError {
                self.state = .failed(message: error.userMessage)
            } catch {
                self.state = .failed(message: Strings.Common.somethingWentWrong)
            }
        }
    }

    func didSelectProduct(_ id: String) {
        guard selectedProductID != id else { return }
        selectedProductID = id
        publishSnapshot()
    }

    func purchaseSelected() {
        guard let id = selectedProductID,
              let product = products.first(where: { $0.id == id }) else { return }
        isPurchasing = true
        publishSnapshot()
        Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await storeKitService.purchase(product)
                self.isPurchasing = false
                self.entitlement = await self.storeKitService.currentEntitlement()
                self.publishSnapshot()
                switch outcome {
                case .success: self.onPurchaseSucceeded?()
                case .userCancelled, .pending: break
                }
            } catch let error as UserFacingError {
                self.isPurchasing = false
                self.publishSnapshot()
                self.onErrorMessage?(error.userMessage)
            } catch {
                self.isPurchasing = false
                self.publishSnapshot()
                self.onErrorMessage?(Strings.Common.somethingWentWrong)
            }
        }
    }

    func restore() {
        isRestoring = true
        publishSnapshot()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await storeKitService.restorePurchases()
                self.entitlement = await self.storeKitService.currentEntitlement()
                self.isRestoring = false
                self.publishSnapshot()
                if case .plus = entitlement {
                    self.onPurchaseSucceeded?()
                }
            } catch let error as UserFacingError {
                self.isRestoring = false
                self.publishSnapshot()
                self.onErrorMessage?(error.userMessage)
            } catch {
                self.isRestoring = false
                self.publishSnapshot()
                self.onErrorMessage?(Strings.Common.somethingWentWrong)
            }
        }
    }

    func didTapClose() {
        onDismiss?()
    }

    private func publishSnapshot() {
        let isPlus: Bool
        switch entitlement {
        case .plus: isPlus = true
        case .free: isPlus = false
        }
        state = .loaded(Snapshot(
            products: products,
            selectedProductID: selectedProductID,
            isPurchasing: isPurchasing,
            isRestoring: isRestoring,
            isCurrentlyPlus: isPlus
        ))
    }

    private func preferredSelection(in products: [SublyProduct]) -> String? {
        if let yearly = products.first(where: { $0.periodUnit == .year }) {
            return yearly.id
        }
        return products.first?.id
    }
}
