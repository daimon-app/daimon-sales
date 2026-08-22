package app.daimon;

import android.app.Activity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.ViewGroup;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.JavascriptInterface;
import org.json.JSONObject;

/**
 * Offline shell for the DAIMON four-mode PWA (morning / work / night / adversity).
 *
 * The PWA is bundled into the APK's assets by the copyPwaAssets Gradle task
 * (see app/build.gradle) and loaded from file:///android_asset/index.html.
 * Product content has no remote origin: navigation is restricted to that asset
 * origin. INTERNET exists solely for Google Play Billing, and the page's own service worker registration (which cannot
 * function under file:// and is a no-op here) is left untouched.
 */
public class MainActivity extends Activity {

    private static final String ASSET_ORIGIN_PREFIX = "file:///android_asset/";
    private static final String START_URL = ASSET_ORIGIN_PREFIX + "index.html";

    private WebView webView;
    private DaimonBilling billing;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);

        // android:///android_asset content stays reachable regardless of this flag;
        // this only governs access to the broader on-device filesystem, which the
        // app has no need for.
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setAllowFileAccessFromFileURLs(false);
        settings.setAllowUniversalAccessFromFileURLs(false);

        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSupportMultipleWindows(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setGeolocationEnabled(false);
        settings.setSaveFormData(false);
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);

        webView.setWebViewClient(new WebViewClient() {
            // The WebResourceRequest overload only exists from API 24 onward; on
            // API 23 (this app's minSdk) it is never invoked by the framework, so
            // the deprecated String overload below must carry the same rule to
            // actually block external navigation on those devices.
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, android.webkit.WebResourceRequest request) {
                return !request.getUrl().toString().startsWith(ASSET_ORIGIN_PREFIX);
            }

            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return !url.startsWith(ASSET_ORIGIN_PREFIX);
            }
        });

        // File chooser is intentionally left unimplemented: the bundled PWA has
        // no file-upload UI, so <input type="file"> must not open a picker.
        webView.setWebChromeClient(new WebChromeClient());
        billing = new DaimonBilling(this, (state, price, message) -> {
            String safeMessage = message == null || message.isEmpty() ? BillingPresentation.message(state) : message;
            String payload = "window.dispatchEvent(new CustomEvent('daimon-billing',{detail:{state:" +
                    JSONObject.quote(state.name()) + ",price:" + JSONObject.quote(price) +
                    ",message:" + JSONObject.quote(safeMessage) + "}}));";
            webView.evaluateJavascript(payload, null);
        });
        webView.addJavascriptInterface(new Object() {
            @JavascriptInterface public void subscribe() { runOnUiThread(() -> billing.purchase()); }
            @JavascriptInterface public void restore() { runOnUiThread(() -> billing.restore()); }
        }, "DaimonBilling");

        webView.loadUrl(START_URL);
        billing.connect();
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK && webView.canGoBack()) {
            webView.goBack();
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            webView.evaluateJavascript(
                "(function(){try{var h=document.getElementById('scrHome');if(h&&!h.classList.contains('on')){resetMode();showLayer('scrHome');return 'home';}}catch(e){}return 'exit';})()",
                result -> { if ("\"exit\"".equals(result)) MainActivity.super.onBackPressed(); }
            );
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onPause() {
        // Stop speech/binaural output before the WebView loses foreground.
        webView.evaluateJavascript("try{AudioHook.stop();}catch(e){}", null);
        webView.onPause();
        webView.pauseTimers();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        webView.onResume();
        webView.resumeTimers();
        if (billing != null) billing.restore();
    }

    @Override
    protected void onDestroy() {
        if (webView.getParent() instanceof ViewGroup) {
            ((ViewGroup) webView.getParent()).removeView(webView);
        }
        webView.removeAllViews();
        if (billing != null) billing.close();
        webView.destroy();
        super.onDestroy();
    }
}
