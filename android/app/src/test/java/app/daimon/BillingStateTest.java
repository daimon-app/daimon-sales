package app.daimon;

import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class BillingStateTest {
    @Test public void purchasedMatchingProductIsEntitled() { assertEquals(BillingState.Entitlement.ENTITLED, BillingState.fromPurchase(1, true)); }
    @Test public void pendingDoesNotGrantEntitlement() { assertEquals(BillingState.Entitlement.PENDING, BillingState.fromPurchase(2, true)); }
    @Test public void wrongProductNeverGrantsEntitlement() { assertEquals(BillingState.Entitlement.NOT_ENTITLED, BillingState.fromPurchase(1, false)); }
}
