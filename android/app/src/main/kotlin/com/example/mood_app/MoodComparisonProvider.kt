package com.example.mood_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * AppWidget "Tu día · Comparar burbujas".
 *
 * No ejecuta Flutter: muestra el PNG que la app rasteriza y guarda con
 * `HomeWidget.saveFile("comparison_image", ...)`. El path del archivo queda
 * guardado en el widget storage con ese mismo key; cuando todavía no existe
 * (recién instalado o sin configurar) se muestra el placeholder.
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

    val imagePath = widgetData.getString("comparison_image", null)
    val bitmap = decodeBitmap(imagePath)
    if (bitmap != null) {
      remoteViews.setImageViewBitmap(R.id.comparison_image, bitmap)
    } else {
      remoteViews.setImageViewResource(R.id.comparison_image, R.drawable.widget_placeholder)
    }

    appWidgetManager.updateAppWidget(appWidgetIds, remoteViews)
  }

  private fun decodeBitmap(path: String?): Bitmap? {
    if (path.isNullOrBlank()) return null
    return try {
      BitmapFactory.decodeFile(path)
    } catch (e: Exception) {
      null
    }
  }
}