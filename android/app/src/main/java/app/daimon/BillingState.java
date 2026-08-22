package app.daimon;

final class BillingState {
    enum Entitlement {
        UNKNOWN, NOT_ENTITLED, PURCHASE_IN_PROGRESS, PURCHASED_UNACKNOWLEDGED,
        ENTITLED, PENDING, GRACE_PERIOD, CANCELED_ACTIVE, EXPIRED, REFUNDED,
        NETWORK_ERROR, PLAY_UNAVAILABLE
    }

    static Entitlement fromPurchase(int purchaseState, boolean productMatches) {
        if (!productMatches) return Entitlement.NOT_ENTITLED;
        if (purchaseState == 1) return Entitlement.ENTITLED;
        if (purchaseState == 2) return Entitlement.PENDING;
        return Entitlement.NOT_ENTITLED;
    }

    private BillingState() {}
}
