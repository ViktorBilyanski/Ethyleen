package com.ethyleen.ethyleen

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.widget.RemoteViews

class FreshnessWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "widget_data"

        fun updateAllWidgets(context: Context) {
            val intent = Intent(context, FreshnessWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FreshnessWidgetProvider::class.java))
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.freshness_widget)

            val freshness = prefs.getString("freshness", "unknown") ?: "unknown"
            val temp = prefs.getString("temperature", "--") ?: "--"
            val humidity = prefs.getString("humidity", "--") ?: "--"
            val battery = prefs.getString("battery", "--") ?: "--"

            // Status pill
            views.setTextViewText(R.id.freshness_pill, freshness.uppercase())

            val color: Int
            val pillBg: Int
            val subtitle: String
            when (freshness) {
                "fresh" -> {
                    color = 0xFF2E7D32.toInt()
                    pillBg = R.drawable.pill_bg_fresh
                    subtitle = "Everything looks good"
                }
                "warning" -> {
                    color = 0xFFE65100.toInt()
                    pillBg = R.drawable.pill_bg_warning
                    subtitle = "Early spoilage signs detected"
                }
                "spoiled" -> {
                    color = 0xFFC62828.toInt()
                    pillBg = R.drawable.pill_bg_spoiled
                    subtitle = "Check your fridge now"
                }
                else -> {
                    color = 0xFF757575.toInt()
                    pillBg = R.drawable.stat_bg
                    subtitle = "Waiting for data..."
                }
            }
            views.setTextColor(R.id.freshness_pill, color)
            views.setInt(R.id.freshness_pill, "setBackgroundResource", pillBg)
            views.setTextViewText(R.id.subtitle_text, subtitle)

            // Stats
            views.setTextViewText(R.id.temp_text, temp)
            views.setTextViewText(R.id.humidity_text, humidity)
            views.setTextViewText(R.id.battery_text, battery)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
