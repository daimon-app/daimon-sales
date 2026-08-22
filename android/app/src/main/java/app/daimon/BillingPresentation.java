package app.daimon;

final class BillingPresentation {
    static boolean unlocks(BillingState.Entitlement state) {
        return state == BillingState.Entitlement.ENTITLED || state == BillingState.Entitlement.GRACE_PERIOD || state == BillingState.Entitlement.CANCELED_ACTIVE;
    }
    static boolean canRetry(BillingState.Entitlement state) {
        return state != BillingState.Entitlement.PURCHASE_IN_PROGRESS && state != BillingState.Entitlement.PURCHASED_UNACKNOWLEDGED;
    }
    static String message(BillingState.Entitlement state) {
        switch (state) {
            case NOT_ENTITLED: return "A monthly plan is required.";
            case PURCHASE_IN_PROGRESS: return "Purchase is in progress.";
            case PURCHASED_UNACKNOWLEDGED: return "Completing purchase verification.";
            case ENTITLED: return "Subscription is active.";
            case PENDING: return "Payment is pending.";
            case GRACE_PERIOD: return "Subscription is in grace period.";
            case CANCELED_ACTIVE: return "Canceled; access remains until expiry.";
            case EXPIRED: return "Subscription has expired.";
            case REFUNDED: return "Purchase was refunded or revoked.";
            case NETWORK_ERROR: return "Network unavailable.";
            case PLAY_UNAVAILABLE: return "Google Play Billing unavailable.";
            default: return "Checking purchase status.";
        }
    }
}
