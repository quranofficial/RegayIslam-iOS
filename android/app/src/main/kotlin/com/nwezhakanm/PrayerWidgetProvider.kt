package com.nwezhakanm

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Item 4: home-screen widget showing today's prayer times for the chosen
 * city, restyled with a gradient card, gold accent and aligned rows so the
 * names and times line up beautifully. Data is written from Dart via
 * home_widget (HomeWidgets.updatePrayer).
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
                    data.getString("prayer_city", null) ?: "")
                setTextViewText(R.id.widget_date,
                    data.getString("prayer_date", null) ?: "")
                setTextViewText(R.id.widget_next,
                    data.getString("prayer_next_name", null) ?: "")
                setTextViewText(R.id.widget_bayani,
                    data.getString("prayer_bayani", null) ?: "--:--")
                setTextViewText(R.id.widget_xorhalatn,
                    data.getString("prayer_xorhalatn", null) ?: "--:--")
                setTextViewText(R.id.widget_niwaro,
                    data.getString("prayer_niwaro", null) ?: "--:--")
                setTextViewText(R.id.widget_asr,
                    data.getString("prayer_asr", null) ?: "--:--")
                setTextViewText(R.id.widget_eywara,
                    data.getString("prayer_eywara", null) ?: "--:--")
                setTextViewText(R.id.widget_esha,
                    data.getString("prayer_esha", null) ?: "--:--")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
