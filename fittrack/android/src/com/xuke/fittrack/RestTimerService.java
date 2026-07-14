package com.xuke.fittrack;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;

import java.util.Locale;

public final class RestTimerService extends Service {
    public static final String ACTION_START = "com.xuke.fittrack.timer.START";
    public static final String ACTION_PAUSE = "com.xuke.fittrack.timer.PAUSE";
    public static final String ACTION_RESUME = "com.xuke.fittrack.timer.RESUME";
    public static final String ACTION_STOP = "com.xuke.fittrack.timer.STOP";
    public static final String EXTRA_REMAINING_MS = "remaining_ms";

    private static final String ACTIVE_CHANNEL_ID = "rest_timer_active";
    static final String COMPLETE_CHANNEL_ID = "rest_timer_complete";
    private static final int ACTIVE_NOTIFICATION_ID = 2001;
    private static final int COMPLETE_NOTIFICATION_ID = 2002;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private long deadlineElapsedMs;
    private long pausedRemainingMs;
    private boolean running;
    private PowerManager.WakeLock wakeLock;

    private final Runnable completionTask = this::complete;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannels();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null || intent.getAction() == null) {
            stopTimer();
            return START_NOT_STICKY;
        }

        long remainingMs = Math.max(0L,
                intent.getLongExtra(EXTRA_REMAINING_MS, 0L));
        switch (intent.getAction()) {
        case ACTION_START:
        case ACTION_RESUME:
            startOrResume(remainingMs);
            break;
        case ACTION_PAUSE:
            pauseTimer(remainingMs);
            break;
        case ACTION_STOP:
            stopTimer();
            break;
        default:
            break;
        }
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(completionTask);
        releaseWakeLock();
        super.onDestroy();
    }

    private void startOrResume(long remainingMs) {
        if (remainingMs <= 0L) {
            stopTimer();
            return;
        }
        running = true;
        pausedRemainingMs = 0L;
        deadlineElapsedMs = SystemClock.elapsedRealtime() + remainingMs;
        notificationManager().cancel(COMPLETE_NOTIFICATION_ID);
        acquireWakeLock(remainingMs);
        handler.removeCallbacks(completionTask);
        handler.postDelayed(completionTask, remainingMs);
        showForegroundNotification(remainingMs, false);
    }

    private void pauseTimer(long remainingMs) {
        if (remainingMs <= 0L) {
            stopTimer();
            return;
        }
        running = false;
        deadlineElapsedMs = 0L;
        pausedRemainingMs = remainingMs;
        handler.removeCallbacks(completionTask);
        releaseWakeLock();
        showForegroundNotification(remainingMs, true);
    }

    private void stopTimer() {
        running = false;
        deadlineElapsedMs = 0L;
        pausedRemainingMs = 0L;
        handler.removeCallbacks(completionTask);
        releaseWakeLock();
        notificationManager().cancel(COMPLETE_NOTIFICATION_ID);
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void complete() {
        if (!running || SystemClock.elapsedRealtime() < deadlineElapsedMs) {
            return;
        }
        running = false;
        releaseWakeLock();
        stopForeground(STOP_FOREGROUND_REMOVE);
        if (notificationsEnabled()) {
            Notification notification = new Notification.Builder(this, COMPLETE_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_stat_fittrack)
                    .setContentTitle("休息结束")
                    .setContentText("可以开始下一组了")
                    .setContentIntent(openAppIntent())
                    .setAutoCancel(true)
                    .setCategory(Notification.CATEGORY_ALARM)
                    .build();
            notificationManager().notify(COMPLETE_NOTIFICATION_ID, notification);
        }
        stopSelf();
    }

    private void showForegroundNotification(long remainingMs, boolean paused) {
        Notification.Builder builder = new Notification.Builder(this, ACTIVE_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_fittrack)
                .setContentTitle(paused ? "组间休息已暂停" : "组间休息")
                .setContentText(paused ? formatDuration(remainingMs) : "倒计时进行中")
                .setContentIntent(openAppIntent())
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_PROGRESS);
        if (!paused) {
            builder.setUsesChronometer(true)
                    .setChronometerCountDown(true)
                    .setWhen(System.currentTimeMillis() + remainingMs);
        }
        Notification notification = builder.build();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ACTIVE_NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(ACTIVE_NOTIFICATION_ID, notification);
        }
    }

    private PendingIntent openAppIntent() {
        Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launchIntent == null) {
            launchIntent = new Intent();
        }
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void createNotificationChannels() {
        NotificationChannel activeChannel = new NotificationChannel(
                ACTIVE_CHANNEL_ID, "组间休息计时", NotificationManager.IMPORTANCE_LOW);
        activeChannel.setDescription("在后台显示当前组间休息剩余时间");
        activeChannel.setSound(null, null);

        NotificationChannel completeChannel = new NotificationChannel(
                COMPLETE_CHANNEL_ID, "休息结束提醒", NotificationManager.IMPORTANCE_HIGH);
        completeChannel.setDescription("组间休息结束时播放一次提醒");

        NotificationManager manager = notificationManager();
        manager.createNotificationChannel(activeChannel);
        manager.createNotificationChannel(completeChannel);
    }

    private NotificationManager notificationManager() {
        return (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    }

    private boolean notificationsEnabled() {
        return RestTimerBridge.completionAlertsEnabled(this);
    }

    private void acquireWakeLock(long remainingMs) {
        if (wakeLock == null) {
            PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
            wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK, "Xunji:RestTimer");
            wakeLock.setReferenceCounted(false);
        }
        if (wakeLock.isHeld()) {
            wakeLock.release();
        }
        wakeLock.acquire(remainingMs + 5000L);
    }

    private void releaseWakeLock() {
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
    }

    private static String formatDuration(long milliseconds) {
        long totalSeconds = (milliseconds + 999L) / 1000L;
        return String.format(Locale.getDefault(), "%02d:%02d",
                totalSeconds / 60L, totalSeconds % 60L);
    }
}
