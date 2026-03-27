package com.reconquer.reconquer_france

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the app after a device reboot so geolocator's foreground location
 * service can resume background tracking automatically.
 *
 * Without this receiver, location tracking (and hex-cell unlocking) stops
 * permanently whenever the phone is restarted until the user manually
 * opens the app again.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return

        launch.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        )
        context.startActivity(launch)
    }
}
