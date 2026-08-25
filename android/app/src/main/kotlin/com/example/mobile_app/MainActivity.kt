package com.example.mobile_app

import android.app.ActivityManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val icon = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
                @Suppress("DEPRECATION")
                val taskDesc = ActivityManager.TaskDescription("HealthLog", icon)
                setTaskDescription(taskDesc)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}