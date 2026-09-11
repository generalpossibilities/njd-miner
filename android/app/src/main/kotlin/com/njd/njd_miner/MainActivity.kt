package com.njd.njd_miner

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Adds one capability the overlay cannot get on its own: reopening the app.
 *
 * When the floating clock is the only thing on screen the app is backgrounded,
 * and Android forbids a background process from starting an activity — except
 * for apps holding SYSTEM_ALERT_WINDOW, which this one already needs for the
 * overlay itself. So the restore button is allowed to work.
 *
 * The overlay runs in its own FlutterEngine, which flutter_overlay_window caches
 * under "myCachedEngine". A channel registered on the main engine is invisible
 * to it, so [attachOverlayBridge] reaches into that cache and registers the same
 * channel on the overlay engine. The main isolate calls it right after showing
 * the overlay, by which point the plugin has created the engine.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "njd/app_control"

        // flutter_overlay_window's OverlayConstants.CACHED_TAG. Not exported by
        // the plugin, so it is duplicated here; if the overlay ever stops
        // reopening the app after a plugin upgrade, check this string first.
        const val OVERLAY_ENGINE_TAG = "myCachedEngine"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        register(flutterEngine)
    }

    private fun register(engine: FlutterEngine) {
        // The app context outlives this activity, which is gone once the app is
        // minimised — exactly when the restore button is used.
        val appContext = applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
            when (call.method) {
                "attachOverlayBridge" -> {
                    val overlayEngine = FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_TAG)
                    if (overlayEngine == null) {
                        result.success(false)
                    } else {
                        register(overlayEngine)
                        result.success(true)
                    }
                }
                "bringAppToFront" -> {
                    result.success(bringAppToFront(appContext))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bringAppToFront(context: Context): Boolean {
        val intent =
            context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return false
        // REORDER_TO_FRONT keeps the existing task rather than starting a second
        // copy, so the app comes back where the user left it.
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        )
        context.startActivity(intent)
        return true
    }
}
