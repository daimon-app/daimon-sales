package app.daimon;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class BillingVerificationClient {
    interface Callback { void onResult(String entitlement, String message); }
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    void verify(String purchaseToken, Callback callback) {
        if (!BuildConfig.BILLING_SERVER_VERIFIED || BuildConfig.BILLING_VERIFICATION_URL.isEmpty()) {
            callback.onResult("INACTIVE", "Billing verification server is not release-verified");
            return;
        }
        executor.execute(() -> {
            HttpURLConnection connection = null;
            try {
                URL url = new URL(BuildConfig.BILLING_VERIFICATION_URL);
                if (!"https".equalsIgnoreCase(url.getProtocol())) throw new SecurityException("HTTPS required");
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("POST");
                connection.setConnectTimeout(5000);
                connection.setReadTimeout(7000);
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                JSONObject body = new JSONObject();
                body.put("purchaseToken", purchaseToken);
                body.put("productId", BuildConfig.BILLING_PRODUCT_ID);
                body.put("packageName", BuildConfig.APPLICATION_ID);
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
                if (connection.getResponseCode() != 200) throw new IllegalStateException("Verification rejected");
                StringBuilder raw = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), StandardCharsets.UTF_8))) {
                    String line; while ((line = reader.readLine()) != null) raw.append(line);
                }
                JSONObject response = new JSONObject(raw.toString());
                callback.onResult(response.optString("entitlement", "INACTIVE"), "");
            } catch (Exception error) {
                // Never include the purchase token or server response in user-visible text/logs.
                callback.onResult("INACTIVE", "Authoritative purchase verification unavailable");
            } finally { if (connection != null) connection.disconnect(); }
        });
    }

    void close() { executor.shutdownNow(); }
}
