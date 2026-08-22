package app.daimon;

final class BillingState {
    enum Entitlement { UNKNOWN, NOT_ENTITLED, PENDING, ENTITLED }

    static Entitlement fromPurchase(int purchaseState, boolean productMatches) {
        if (!productMatches) return Entitlement.NOT_ENTITLED;
        if (purchaseState == 1) return Entitlement.ENTITLED;
        if (purchaseState == 2) return Entitlement.PENDING;
        return Entitlement.NOT_ENTITLED;
    }

    private BillingState() {}
}
