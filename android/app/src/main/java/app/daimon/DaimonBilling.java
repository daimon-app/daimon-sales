package app.daimon;

import android.app.Activity;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import java.util.Collections;
import java.util.List;

final class DaimonBilling implements PurchasesUpdatedListener {
    interface Listener { void onBillingState(BillingState.Entitlement state, String price, String message); }

    private final Activity activity;
    private final Listener listener;
    private final BillingClient client;
    private final BillingVerificationClient verifier = new BillingVerificationClient();
    private ProductDetails productDetails;

    DaimonBilling(Activity activity, Listener listener) {
        this.activity = activity;
        this.listener = listener;
        client = BillingClient.newBuilder(activity)
                .setListener(this)
                .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                .build();
    }

    void connect() {
        if (client.isReady()) { queryPurchases(); return; }
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(BillingResult result) {
                if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    queryProduct(); queryPurchases();
                } else notifyState(BillingState.Entitlement.UNKNOWN, "", result.getDebugMessage());
            }
            @Override public void onBillingServiceDisconnected() {
                notifyState(BillingState.Entitlement.UNKNOWN, "", "Play Billing disconnected");
            }
        });
    }

    void purchase() {
        if (!BuildConfig.BILLING_IDS_VERIFIED) { notifyState(BillingState.Entitlement.PLAY_UNAVAILABLE, "", "Billing IDs are provisional"); return; }
        if (!client.isReady() || productDetails == null) { connect(); notifyState(BillingState.Entitlement.UNKNOWN, "", "Product is not ready"); return; }
        List<ProductDetails.SubscriptionOfferDetails> offers = productDetails.getSubscriptionOfferDetails();
        if (offers == null || offers.isEmpty()) { notifyState(BillingState.Entitlement.UNKNOWN, "", "No eligible subscription offer"); return; }
        ProductDetails.SubscriptionOfferDetails selected = null;
        for (ProductDetails.SubscriptionOfferDetails offer : offers) {
            if (BuildConfig.BILLING_BASE_PLAN_ID.equals(offer.getBasePlanId())) { selected = offer; break; }
        }
        if (selected == null) { notifyState(BillingState.Entitlement.UNKNOWN, "", "Configured base plan is unavailable"); return; }
        BillingFlowParams.ProductDetailsParams item = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(productDetails).setOfferToken(selected.getOfferToken()).build();
        notifyState(BillingState.Entitlement.PURCHASE_IN_PROGRESS, "", "");
        BillingResult result = client.launchBillingFlow(activity, BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(Collections.singletonList(item)).build());
        if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) notifyState(BillingState.Entitlement.UNKNOWN, "", result.getDebugMessage());
    }

    void restore() { if (client.isReady()) queryPurchases(); else connect(); }
    void close() { verifier.close(); if (client.isReady()) client.endConnection(); }

    private void queryProduct() {
        QueryProductDetailsParams.Product product = QueryProductDetailsParams.Product.newBuilder()
                .setProductId(BuildConfig.BILLING_PRODUCT_ID).setProductType(BillingClient.ProductType.SUBS).build();
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder()
                .setProductList(Collections.singletonList(product)).build(), (result, queryResult) -> {
            List<ProductDetails> details = queryResult.getProductDetailsList();
            productDetails = details.isEmpty() ? null : details.get(0);
            String price = "";
            if (productDetails != null && productDetails.getSubscriptionOfferDetails() != null) {
                for (ProductDetails.SubscriptionOfferDetails offer : productDetails.getSubscriptionOfferDetails()) {
                    if (BuildConfig.BILLING_BASE_PLAN_ID.equals(offer.getBasePlanId()) && !offer.getPricingPhases().getPricingPhaseList().isEmpty()) {
                        price = offer.getPricingPhases().getPricingPhaseList().get(0).getFormattedPrice(); break;
                    }
                }
            }
            notifyState(BillingState.Entitlement.UNKNOWN, price, result.getDebugMessage());
        });
    }

    private void queryPurchases() {
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
                (result, purchases) -> processPurchases(result, purchases));
    }

    @Override public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
        processPurchases(result, purchases == null ? Collections.emptyList() : purchases);
    }

    private void processPurchases(BillingResult result, List<Purchase> purchases) {
        if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) { notifyState(BillingState.Entitlement.UNKNOWN, "", result.getDebugMessage()); return; }
        BillingState.Entitlement entitlement = BillingState.Entitlement.NOT_ENTITLED;
        for (Purchase purchase : purchases) {
            boolean matches = purchase.getProducts().contains(BuildConfig.BILLING_PRODUCT_ID);
            BillingState.Entitlement current = BillingState.fromPurchase(purchase.getPurchaseState(), matches);
            if (current == BillingState.Entitlement.ENTITLED) {
                entitlement = purchase.isAcknowledged() ? BillingState.Entitlement.UNKNOWN : BillingState.Entitlement.PURCHASED_UNACKNOWLEDGED;
                verifyAuthoritatively(purchase);
                break;
            }
            if (current == BillingState.Entitlement.PENDING) entitlement = current;
        }
        notifyState(entitlement, "", "");
    }

    private void verifyAuthoritatively(Purchase purchase) {
        verifier.verify(purchase.getPurchaseToken(), (verdict, lifecycle, message) -> {
            if ("ACTIVE".equals(verdict)) {
                BillingState.Entitlement authoritative = parseLifecycle(lifecycle);
                if (!BillingPresentation.unlocks(authoritative)) {
                    notifyState(authoritative, "", message);
                    return;
                }
                if (purchase.isAcknowledged()) notifyState(authoritative, "", message);
                else client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.getPurchaseToken()).build(), result -> {
                    if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) notifyState(authoritative, "", message);
                    else notifyState(BillingState.Entitlement.PURCHASED_UNACKNOWLEDGED, "", "Purchase acknowledgement failed");
                });
            } else notifyState(parseLifecycle(lifecycle), "", message);
        });
    }

    private BillingState.Entitlement parseLifecycle(String lifecycle) {
        try { return BillingState.Entitlement.valueOf(lifecycle); }
        catch (IllegalArgumentException error) { return BillingState.Entitlement.NOT_ENTITLED; }
    }

    private void notifyState(BillingState.Entitlement state, String price, String message) {
        activity.runOnUiThread(() -> listener.onBillingState(state, price, message));
    }
}
