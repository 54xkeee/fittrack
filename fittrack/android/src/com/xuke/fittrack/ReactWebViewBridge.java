package com.xuke.fittrack;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.net.Uri;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import java.io.ByteArrayInputStream;
public final class ReactWebViewBridge {
    private static final String START_URL = "file:///android_asset/react/index.html";
    private static Activity activity;
    private static WebView webView;

    private ReactWebViewBridge() {}

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    public static void show(Activity targetActivity) {
        if (targetActivity == null) return;
        targetActivity.runOnUiThread(() -> {
            activity = targetActivity;
            if (webView != null) return;

            WebView view = new WebView(targetActivity);
            view.setBackgroundColor(Color.rgb(245, 247, 251));
            WebSettings settings = view.getSettings();
            settings.setJavaScriptEnabled(true);
            settings.setDomStorageEnabled(false);
            settings.setAllowContentAccess(false);
            settings.setAllowFileAccess(true);
            settings.setBlockNetworkLoads(true);
            settings.setMediaPlaybackRequiresUserGesture(true);
            view.addJavascriptInterface(new FitTrackApi(), "FitTrackNative");
            view.setWebViewClient(new LocalOnlyClient());

            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT);
            ViewGroup content = targetActivity.findViewById(android.R.id.content);
            content.addView(view, params);
            webView = view;
            view.loadUrl(START_URL);
        });
    }

    public static void hide() {
        Activity target = activity;
        if (target == null) return;
        target.runOnUiThread(() -> {
            WebView view = webView;
            webView = null;
            if (view == null) return;
            ViewGroup parent = (ViewGroup) view.getParent();
            if (parent != null) parent.removeView(view);
            view.removeJavascriptInterface("FitTrackNative");
            view.stopLoading();
            view.destroy();
        });
    }

    public static boolean handleBack() {
        WebView view = webView;
        if (view == null) return false;
        nativeSuppressForSession();
        return true;
    }

    private static final class LocalOnlyClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            return !"file".equals(uri.getScheme())
                || !uri.toString().startsWith("file:///android_asset/react/");
        }

        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            String scheme = request.getUrl().getScheme();
            if ("http".equals(scheme) || "https".equals(scheme)) {
                return new WebResourceResponse(
                    "text/plain", "UTF-8",
                    new ByteArrayInputStream(new byte[0]));
            }
            return super.shouldInterceptRequest(view, request);
        }
    }

    public static final class FitTrackApi {
        @JavascriptInterface public String getSnapshot() { return nativeGetSnapshot(); }
        @JavascriptInterface public boolean updateSet(String id, double weightKg, int reps) {
            return nativeUpdateSet(id, weightKg, reps);
        }
        @JavascriptInterface public boolean completeSet(String id) { return nativeCompleteSet(id); }
        @JavascriptInterface public boolean addSet() { return nativeAddSet(); }
        @JavascriptInterface public boolean openNextExercise() { return nativeOpenNextExercise(); }
        @JavascriptInterface public void pauseRest() { nativePauseRest(); }
        @JavascriptInterface public void skipRest() { nativeSkipRest(); }
        @JavascriptInterface public boolean finishWorkout() { return nativeFinishWorkout(); }
        @JavascriptInterface public void close() { nativeSuppressForSession(); }
    }

    private static native String nativeGetSnapshot();
    private static native boolean nativeUpdateSet(String setId, double weightKg, int reps);
    private static native boolean nativeCompleteSet(String setId);
    private static native boolean nativeAddSet();
    private static native boolean nativeOpenNextExercise();
    private static native void nativePauseRest();
    private static native void nativeSkipRest();
    private static native boolean nativeFinishWorkout();
    private static native void nativeSuppressForSession();
}
