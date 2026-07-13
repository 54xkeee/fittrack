package com.fittrack.app;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

public final class RestTimerBridge {
    private static final int NOTIFICATION_PERMISSION_REQUEST = 4102;

    private RestTimerBridge() {}

    public static void start(Context context, int durationSeconds) {
        requestNotificationPermission(context);
        Intent intent = serviceIntent(context, RestTimerService.ACTION_START);
        intent.putExtra(RestTimerService.EXTRA_REMAINING_MS,
                Math.max(1, durationSeconds) * 1000L);
        context.startForegroundService(intent);
    }

    public static void pause(Context context, long remainingMilliseconds) {
        sendUpdate(context, RestTimerService.ACTION_PAUSE, remainingMilliseconds);
    }

    public static void resume(Context context, long remainingMilliseconds) {
        sendUpdate(context, RestTimerService.ACTION_RESUME, remainingMilliseconds);
    }

    public static void stop(Context context) {
        context.startService(serviceIntent(context, RestTimerService.ACTION_STOP));
    }

    private static void sendUpdate(Context context, String action, long remainingMilliseconds) {
        Intent intent = serviceIntent(context, action);
        intent.putExtra(RestTimerService.EXTRA_REMAINING_MS,
                Math.max(0L, remainingMilliseconds));
        context.startService(intent);
    }

    private static Intent serviceIntent(Context context, String action) {
        Intent intent = new Intent(context, RestTimerService.class);
        intent.setAction(action);
        return intent;
    }

    private static void requestNotificationPermission(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
                || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    == PackageManager.PERMISSION_GRANTED
                || !(context instanceof Activity)) {
            return;
        }
        Activity activity = (Activity) context;
        activity.runOnUiThread(() -> activity.requestPermissions(
                new String[]{Manifest.permission.POST_NOTIFICATIONS},
                NOTIFICATION_PERMISSION_REQUEST));
    }
}
