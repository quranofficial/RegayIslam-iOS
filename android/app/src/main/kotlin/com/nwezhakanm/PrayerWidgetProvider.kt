package com.nwezhakanm

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Item 4: home-screen widget showing today's prayer times for the chosen
 * city. Data is written from Dart via home_widget (HomeWidgets.updatePrayer).
 */
class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val data = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_prayer).apply {
                setTextViewText(R.id.widget_city,
                    data.getString("prayer_city", null) ?: "ڕێگای ئیسلام")
                setTextViewText(R.id.widget_date,
                    data.getString("prayer_date", null) ?: "")
                setTextViewText(R.id.widget_next,
                    "${data.getString("prayer_next_name", null) ?: ""} ${data.getString("prayer_next_time", null) ?: ""}")
                setTextViewText(R.id.widget_fajr,
                    "بەیانی  ${data.getString("prayer_bayani", null) ?: "--:--"}")
                setTextViewText(R.id.widget_dhuhr,
                    "نیوەڕۆ  ${data.getString("prayer_niwaro", null) ?: "--:--"}")
                setTextViewText(R.id.widget_asr,
                    "عەسر  ${data.getString("prayer_asr", null) ?: "--:--"}")
                setTextViewText(R.id.widget_maghrib,
                    "ئێوارە  ${data.getString("prayer_eywara", null) ?: "--:--"}")
                setTextViewText(R.id.widget_isha,
                    "خەوتنان  ${data.getString("prayer_esha", null) ?: "--:--"}")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
