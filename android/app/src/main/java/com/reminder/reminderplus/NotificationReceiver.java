package com.reminder.reminderplus;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

public class NotificationReceiver extends BroadcastReceiver {
    private static final String TAG = "NotificationReceiver";
    private static final String CHANNEL_ID = "reminder_channel";

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            Log.d(TAG, "NotificationReceiver triggered");

            int notificationId = intent.getIntExtra("notification_id", 0);
            String title = intent.getStringExtra("title");
            String body = intent.getStringExtra("body");
            String payload = intent.getStringExtra("payload");

            Log.d(TAG, "Showing notification - ID: " + notificationId + 
                      ", Title: " + title + ", Body: " + body + 
                      ", Payload: " + payload);

            // Create notification channel if not exists
            createNotificationChannel(context);

            // Create intent for when notification is tapped
            Intent tapIntent = new Intent(context, MainActivity.class);
            tapIntent.putExtra("notification_id", notificationId);
            tapIntent.putExtra("payload", payload);
            tapIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

            android.app.PendingIntent pendingIntent = android.app.PendingIntent.getActivity(
                context, 
                notificationId, 
                tapIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT | android.app.PendingIntent.FLAG_IMMUTABLE
            );

            // Build the notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
                .setVibrate(new long[]{0, 250, 250, 250})
                .setLights(0xFF8A2BE2, 1000, 500)
                .setDefaults(NotificationCompat.DEFAULT_ALL);

            // Show the notification
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.notify(notificationId, builder.build());

            Log.d(TAG, "Notification displayed successfully");

        } catch (Exception e) {
            Log.e(TAG, "Error in NotificationReceiver: " + e.getMessage(), e);
        }
    }

    private void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Reminder Notifications",
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Scheduled reminder notifications");
            channel.enableLights(true);
            channel.enableVibration(true);
            channel.setShowBadge(true);

            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
                Log.d(TAG, "Notification channel created in receiver");
            }
        }
    }
}
