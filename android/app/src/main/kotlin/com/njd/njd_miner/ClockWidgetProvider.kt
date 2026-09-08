package com.njd.njd_miner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget. A `RemoteViews` layout cannot run Flutter or the WASM
 * miner, so it only renders the last values pushed from Dart
 * (`HomeWidgetBridge.update`): the analog-free digital time via a native
 * `TextClock`, plus NACKL balance and mining status. Tapping it opens the
 * full-screen clock activity, which is where mining actually happens.
 */
class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.clock_widget).apply {
                setTextViewText(
                    R.id.widget_balance,
                    (data.getString("nackl_balance", "—") ?: "—") + " NACKL",
                )
                setTextViewText(
                    R.id.widget_status,
                    data.getString("mining_status", "idle") ?: "idle",
                )

                val launch = Intent(context, MainActivity::class.java)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(context, 0, launch, flags),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
