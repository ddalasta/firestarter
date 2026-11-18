package app.firestarter.remote;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * The whole app: one full-screen web view that opens the remote page from the
 * fireplace box. The page itself still comes from GitHub (through the box), so
 * page updates arrive without reinstalling this app.
 */
public class MainActivity extends Activity {
    // The fireplace box. Only reachable on the home WiFi.
    private static final String BOX_HOST = "192.168.7.254";
    private static final String HOME = "http://" + BOX_HOST + "/";

    private WebView web;
    private boolean offline;

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        web = new WebView(this);
        web.setBackgroundColor(Color.BLACK);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);   // the page keeps the LIFX key and last room here

        // Needed so the page's "Turn the fireplace ON?" question actually shows.
        // Without this a web view silently answers "no" to every confirm().
        web.setWebChromeClient(new WebChromeClient());

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (BOX_HOST.equals(request.getUrl().getHost())) return false;   // stay in the app
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, request.getUrl()));   // other links: browser
                } catch (Exception ignored) { }
                return true;
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) showOffline();
            }
        });

        web.loadUrl(HOME);
    }

    /** Shown when the box can't be reached (usually: not on the home WiFi). */
    private void showOffline() {
        offline = true;
        String html = "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
            + "<style>body{background:#000;color:#eee;font-family:sans-serif;text-align:center;padding:30vh 28px 0}"
            + "h1{font-size:22px}p{color:#aaa;font-size:16px;line-height:1.4}"
            + "a{display:inline-block;margin-top:18px;padding:14px 26px;border-radius:14px;background:#ff7a2f;"
            + "color:#1a0d05;font-weight:bold;font-size:17px;text-decoration:none}</style></head><body>"
            + "<h1>Can't find the fireplace</h1>"
            + "<p>This app only works on the home WiFi. Connect to it and try again.</p>"
            + "<a href='" + HOME + "'>Try again</a></body></html>";
        web.loadDataWithBaseURL(null, html, "text/html", "utf-8", null);
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Coming back to the app after the "can't find" screen: try again by itself.
        if (offline) {
            offline = false;
            web.loadUrl(HOME);
        }
    }

    @Override
    protected void onDestroy() {
        if (web != null) web.destroy();
        super.onDestroy();
    }
}
