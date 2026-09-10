package com.example.mood_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * AppWidget "Tu día · Comparar burbujas".
 *
 * No ejecuta Flutter: dibuja la escena en NATIVO con
 * [ComparisonWidgetPainter] a partir del cache que la app deja en el widget
 * storage (colores + etiquetas de hoy). Mientras no haya cache (recién
 * instalado o sin configurar) se muestra el placeholder.
 */
class MoodComparisonProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val remoteViews = RemoteViews(context.packageName, R.layout.widget_comparison)

    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
    if (launchIntent != null) {
      val pendingIntent = PendingIntent.getActivity(
          context,
          0,
          launchIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      remoteViews.setOnClickPendingIntent(R.id.widget_comparison_root, pendingIntent)
    }

    val dateKey = widgetData.getString("widget_date_key", null)
    val mineJson = widgetData.getString("widget_mine_json", null)
    val friendJson = widgetData.getString("widget_friend_json", null)
    if (mineJson != null && friendJson != null) {
      val bitmap = ComparisonWidgetPainter.draw(dateKey, mineJson, friendJson)
      remoteViews.setImageViewBitmap(R.id.comparison_image, bitmap)
    } else {
      remoteViews.setImageViewResource(R.id.comparison_image, R.drawable.widget_placeholder)
    }

    appWidgetManager.updateAppWidget(appWidgetIds, remoteViews)
  }
}