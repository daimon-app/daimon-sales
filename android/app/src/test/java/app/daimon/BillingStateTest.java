package app.daimon;

import org.junit.Test;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class BillingStateTest {
    @Test public void purchasedMatchingProductIsEntitled() { assertEquals(BillingState.Entitlement.ENTITLED, BillingState.fromPurchase(1, true)); }
    @Test public void pendingDoesNotGrantEntitlement() { assertEquals(BillingState.Entitlement.PENDING, BillingState.fromPurchase(2, true)); }
    @Test public void wrongProductNeverGrantsEntitlement() { assertEquals(BillingState.Entitlement.NOT_ENTITLED, BillingState.fromPurchase(1, false)); }
    @Test public void everyLifecycleStateHasPresentation() {
        for (BillingState.Entitlement state : BillingState.Entitlement.values()) assertFalse(BillingPresentation.message(state).isEmpty());
    }
    @Test public void onlyActiveLifecycleStatesUnlockContent() {
        for (BillingState.Entitlement state : BillingState.Entitlement.values()) {
            boolean expected = state == BillingState.Entitlement.ENTITLED || state == BillingState.Entitlement.GRACE_PERIOD || state == BillingState.Entitlement.CANCELED_ACTIVE;
            assertEquals(expected, BillingPresentation.unlocks(state));
        }
    }
    @Test public void inFlightStatesDisableRetry() {
        assertFalse(BillingPresentation.canRetry(BillingState.Entitlement.PURCHASE_IN_PROGRESS));
        assertFalse(BillingPresentation.canRetry(BillingState.Entitlement.PURCHASED_UNACKNOWLEDGED));
        assertTrue(BillingPresentation.canRetry(BillingState.Entitlement.NETWORK_ERROR));
    }
}
