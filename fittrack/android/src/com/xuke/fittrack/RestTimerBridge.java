package com.xuke.fittrack;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

public final class RestTimerBridge {
    public static final int BACKGROUND_ALERT_UNSUPPORTED = 0;
    public static final int BACKGROUND_ALERT_AVAILABLE = 1;
    public static final int BACKGROUND_ALERT_REQUESTABLE = 2;
    public static final int BACKGROUND_ALERT_DISABLED = 3;

    private static final int NOTIFICATION_PERMISSION_REQUEST = 4102;
    private static final String PREFERENCES_NAME = "rest_timer_notifications";
    private static final String PERMISSION_REQUESTED_KEY = "permission_requested";

    private RestTimerBridge() {}

    public static boolean start(Context context, int durationSeconds) {
        Intent intent = serviceIntent(context, RestTimerService.ACTION_START);
        intent.putExtra(RestTimerService.EXTRA_REMAINING_MS,
                Math.max(1, durationSeconds) * 1000L);
        try {
            context.startForegroundService(intent);
            return true;
        } catch (RuntimeException exception) {
            return false;
        }
    }

    public static void pause(Context context, long remainingMilliseconds) {
        sendUpdate(context, RestTimerService.ACTION_PAUSE, remainingMilliseconds);
    }

    public static void resume(Context context, long remainingMilliseconds) {
        sendUpdate(context, RestTimerService.ACTION_RESUME, remainingMilliseconds);
    }

    public static void stop(Context context) {
        startServiceSafely(context, serviceIntent(context, RestTimerService.ACTION_STOP));
    }

    private static void sendUpdate(Context context, String action, long remainingMilliseconds) {
        Intent intent = serviceIntent(context, action);
        intent.putExtra(RestTimerService.EXTRA_REMAINING_MS,
                Math.max(0L, remainingMilliseconds));
        startServiceSafely(context, intent);
    }

    private static boolean startServiceSafely(Context context, Intent intent) {
        try {
            context.startService(intent);
            return true;
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    private static Intent serviceIntent(Context context, String action) {
        Intent intent = new Intent(context, RestTimerService.class);
        intent.setAction(action);
        return intent;
    }

    public static int backgroundAlertState(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null) {
            return BACKGROUND_ALERT_DISABLED;
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return completionAlertsEnabled(context, manager)
                    ? BACKGROUND_ALERT_AVAILABLE : BACKGROUND_ALERT_DISABLED;
        }

        boolean granted = context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                == PackageManager.PERMISSION_GRANTED;
        if (granted) {
            return completionAlertsEnabled(context, manager)
                    ? BACKGROUND_ALERT_AVAILABLE : BACKGROUND_ALERT_DISABLED;
        }

        boolean requested = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getBoolean(PERMISSION_REQUESTED_KEY, false);
        return requested ? BACKGROUND_ALERT_DISABLED : BACKGROUND_ALERT_REQUESTABLE;
    }

    static boolean completionAlertsEnabled(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        return manager != null && completionAlertsEnabled(context, manager);
    }

    private static boolean completionAlertsEnabled(
            Context context, NotificationManager manager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
            return false;
        }
        if (!manager.areNotificationsEnabled()) {
            return false;
        }
        NotificationChannel channel = manager.getNotificationChannel(
                RestTimerService.COMPLETE_CHANNEL_ID);
        return channel == null || channel.getImportance() != NotificationManager.IMPORTANCE_NONE;
    }

    public static boolean requestNotificationPermission(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
                || backgroundAlertState(context) != BACKGROUND_ALERT_REQUESTABLE
                || !(context instanceof Activity)) {
            return false;
        }

        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PERMISSION_REQUESTED_KEY, true)
                .apply();
        Activity activity = (Activity) context;
        activity.runOnUiThread(() -> {
            try {
                activity.requestPermissions(
                        new String[]{Manifest.permission.POST_NOTIFICATIONS},
                        NOTIFICATION_PERMISSION_REQUEST);
            } catch (RuntimeException ignored) {
                // The in-app timer remains usable when the system cannot show the prompt.
            }
        });
        return true;
    }

    public static boolean openNotificationSettings(Context context) {
        Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName());
        if (!(context instanceof Activity)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        try {
            context.startActivity(intent);
            return true;
        } catch (RuntimeException firstFailure) {
            Intent fallback = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:" + context.getPackageName()));
            if (!(context instanceof Activity)) {
                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            try {
                context.startActivity(fallback);
                return true;
            } catch (RuntimeException ignored) {
                return false;
            }
        }
    }
}
