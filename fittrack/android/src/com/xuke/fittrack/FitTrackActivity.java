package com.xuke.fittrack;

import android.os.Build;
import android.os.Bundle;
import android.window.OnBackInvokedCallback;

import org.qtproject.qt.android.bindings.QtActivity;

public class FitTrackActivity extends QtActivity {
    private OnBackInvokedCallback backCallback;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback = () -> {
                if (!ReactWebViewBridge.handleBack()) finish();
            };
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback);
        }
    }

    @SuppressWarnings("deprecation")
    @Override
    public void onBackPressed() {
        if (ReactWebViewBridge.handleBack()) return;
        super.onBackPressed();
    }

    @Override
    public void onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backCallback != null) {
            getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(backCallback);
        }
        super.onDestroy();
    }
}
