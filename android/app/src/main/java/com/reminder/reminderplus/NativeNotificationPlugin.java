package com.reminder.reminderplus;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class NativeNotificationPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "NativeNotificationPlugin";
    private static final String CHANNEL_NAME = "native_notifications";
    
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        Log.d(TAG, "NativeNotificationPlugin attached to engine");
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            switch (call.method) {
                case "scheduleNotification":
                    handleScheduleNotification(call, result);
                    break;
                case "cancelNotification":
                    handleCancelNotification(call, result);
                    break;
                case "initialize":
                    handleInitialize(result);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in method call: " + e.getMessage(), e);
            result.error("METHOD_ERROR", e.getMessage(), null);
        }
    }

    private void handleScheduleNotification(MethodCall call, Result result) {
        try {
            int id = call.argument("id");
            String title = call.argument("title");
            String body = call.argument("body");
            long triggerTime = call.argument("triggerTime");
            String payload = call.argument("payload");

            Log.d(TAG, "Scheduling notification - ID: " + id + 
                      ", Title: " + title + ", Time: " + triggerTime);

            NotificationScheduler.scheduleNotification(context, id, title, body, triggerTime, payload);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Error scheduling notification: " + e.getMessage(), e);
            result.error("SCHEDULE_ERROR", e.getMessage(), null);
        }
    }

    private void handleCancelNotification(MethodCall call, Result result) {
        try {
            int id = call.argument("id");
            Log.d(TAG, "Cancelling notification - ID: " + id);
            
            NotificationScheduler.cancelNotification(context, id);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Error cancelling notification: " + e.getMessage(), e);
            result.error("CANCEL_ERROR", e.getMessage(), null);
        }
    }

    private void handleInitialize(Result result) {
        try {
            Log.d(TAG, "Initializing native notification plugin");
            NotificationScheduler.createNotificationChannel(context);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Error initializing: " + e.getMessage(), e);
            result.error("INIT_ERROR", e.getMessage(), null);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        Log.d(TAG, "NativeNotificationPlugin detached from engine");
    }
}
