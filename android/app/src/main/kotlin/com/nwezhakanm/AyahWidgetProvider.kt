package com.nwezhakanm

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Item 4: home-screen widget showing the daily Quran ayah
 * (HomeWidgets.updateAyah writes ayah_text / ayah_ref).
 */
class AyahWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val data = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_ayah).apply {
                setTextViewText(R.id.widget_ayah_text,
                    data.getString("ayah_text", null)
                        ?: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ")
                setTextViewText(R.id.widget_ayah_ref,
                    data.getString("ayah_ref", null) ?: "ئایەتی ڕۆژ — ڕێگای ئیسلام")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
