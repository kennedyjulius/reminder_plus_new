package com.reminder.reminderplus;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import java.util.Calendar;

public class NotificationScheduler {
    private static final String TAG = "NotificationScheduler";
    private static final String CHANNEL_ID = "reminder_channel";
    private static final String CHANNEL_NAME = "Reminder Notifications";
    private static final String CHANNEL_DESCRIPTION = "Scheduled reminder notifications";

    public static void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription(CHANNEL_DESCRIPTION);
            channel.enableLights(true);
            channel.enableVibration(true);
            channel.setShowBadge(true);

            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
                Log.d(TAG, "Notification channel created successfully");
            }
        }
    }

    public static void scheduleNotification(Context context, int notificationId, String title, 
                                          String body, long triggerTime, String payload) {
        try {
            Log.d(TAG, "Scheduling notification - ID: " + notificationId + 
                      ", Title: " + title + ", Time: " + triggerTime + 
                      ", Payload: " + payload);

            // Create notification channel
            createNotificationChannel(context);

            // Create intent for the notification
            Intent intent = new Intent(context, MainActivity.class);
            intent.putExtra("notification_id", notificationId);
            intent.putExtra("payload", payload);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

            PendingIntent pendingIntent = PendingIntent.getActivity(
                context, 
                notificationId, 
                intent, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            // Create the notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info) // Use a simple icon
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setWhen(triggerTime)
                .setShowWhen(true)
                .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
                .setVibrate(new long[]{0, 250, 250, 250})
                .setLights(0xFF8A2BE2, 1000, 500);

            // Schedule the notification using AlarmManager
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager != null) {
                Intent alarmIntent = new Intent(context, NotificationReceiver.class);
                alarmIntent.putExtra("notification_id", notificationId);
                alarmIntent.putExtra("title", title);
                alarmIntent.putExtra("body", body);
                alarmIntent.putExtra("payload", payload);

                PendingIntent alarmPendingIntent = PendingIntent.getBroadcast(
                    context, 
                    notificationId, 
                    alarmIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );

                // Use setExactAndAllowWhileIdle for better reliability
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, 
                        triggerTime, 
                        alarmPendingIntent
                    );
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP, 
                        triggerTime, 
                        alarmPendingIntent
                    );
                }

                Log.d(TAG, "Notification scheduled successfully for: " + new java.util.Date(triggerTime));
            } else {
                Log.e(TAG, "AlarmManager is null");
            }

        } catch (Exception e) {
            Log.e(TAG, "Error scheduling notification: " + e.getMessage(), e);
        }
    }

    public static void cancelNotification(Context context, int notificationId) {
        try {
            Log.d(TAG, "Cancelling notification with ID: " + notificationId);
            
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager != null) {
                Intent intent = new Intent(context, NotificationReceiver.class);
                PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    context, 
                    notificationId, 
                    intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                alarmManager.cancel(pendingIntent);
                Log.d(TAG, "Notification cancelled successfully");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error cancelling notification: " + e.getMessage(), e);
        }
    }
}
