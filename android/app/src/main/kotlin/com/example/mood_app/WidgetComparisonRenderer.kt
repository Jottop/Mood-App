package com.example.mood_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.ArrayList

/**
 * Render compartido de los widgets de comparación (HORIZONTAL y VERTICAL).
 *
 * Lee el cache que la app deja en el widget storage (fecha + burbuja mía +
 * burbuja del amigo), pinta la escena con [ComparisonWidgetPainter] al tamaño
 * REAL que el launcher le dio al widget (rescatado de
 * [AppWidgetManager.getAppWidgetOptions]) y actualiza el AppWidget. Sin cache
 * se muestra el placeholder.
 *
 * Como la geometría del painter se deriva del lado corto del lienzo, al
 * redimensionar el widget en el escritorio la escena se re-adapta sin
 * espacios vacíos: basta estirar el vertical a mano hasta que su marco sea el
 * transpuesto del horizontal y las burbujas quedan del mismo tamaño.
 */
object WidgetComparisonRenderer {

  /** Cacheto el layout usado por ambos providers (bitmap + clic). */
  fun render(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
    layout: String,
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
    // Color de fondo elegido por el usuario (ARGB); -1 = sin personalizar.
    val bgArgb = widgetData.getInt("widget_bg_argb", -1)

    if (mineJson != null && friendJson != null) {
      for (widgetId in appWidgetIds) {
        val (targetWidth, targetHeight) = widgetSize(context, appWidgetManager, widgetId)
        val bitmap =
            ComparisonWidgetPainter.draw(dateKey, mineJson, friendJson, layout,
                targetWidth, targetHeight, bgArgb)
        remoteViews.setImageViewBitmap(R.id.comparison_image, bitmap)
        appWidgetManager.updateAppWidget(widgetId, remoteViews)
      }
    } else {
      remoteViews.setImageViewResource(R.id.comparison_image, R.drawable.widget_placeholder)
      appWidgetManager.updateAppWidget(appWidgetIds, remoteViews)
    }
  }

  /**
   * Hint best-effort (Android 12+, lo honra el launcher si quiere): le pedimos
   * al launcher que el widget vertical pueda adoptar el tamaño EXACTO que es el
   * transpuesto del marco real del widget horizontal (ancho↔alto). Si el
   * launcher ignora esto (One UI decide sus propias medidas), no rompe nada:
   * el default del provider ya es 2×2 y el painter se auto-ajusta a cualquier
   * marco. Se llama SOLO sobre el widget vertical.
   */
  fun suggestTransposedSize(
    context: Context,
    appWidgetManager: AppWidgetManager,
    verticalWidgetId: Int,
  ) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

    val horizontalProvider = ComponentName(context, MoodComparisonProvider::class.java)
    val horizontalIds = appWidgetManager.getAppWidgetIds(horizontalProvider)
    if (horizontalIds.isEmpty()) return

    val horizontalSize = widgetSize(context, appWidgetManager, horizontalIds.first())
    if (horizontalSize.first <= 0 || horizontalSize.second <= 0) return

    val density = context.resources.displayMetrics.density
    // Transpuesto del horizontal, en dp (el launcher espera dp en OPTION_APPWIDGET_SIZES).
    val transposed = SizeF(horizontalSize.second / density, horizontalSize.first / density)
    val sizes = ArrayList<SizeF>().apply { add(transposed) }

    val options = Bundle().apply {
      putParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, sizes)
    }
    try {
      appWidgetManager.updateAppWidgetOptions(verticalWidgetId, options)
    } catch (_: Exception) {
      // Ignorado por launcher que no soporta tamaños sugeridos.
    }
  }

  /** Tamaño real del widget en px (ancho, alto) según las opciones que el
   *  launcher reporta (dp → px con la densidad del dispositivo). Si el
   *  launcher no reporta medidas, devuelve (0, 0) y el painter usa sus
   *  tamaños por defecto. */
  private fun widgetSize(
    context: Context,
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
  ): Pair<Int, Int> {
    val options: Bundle = appWidgetManager.getAppWidgetOptions(widgetId)
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
    val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
    val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
    if (minWidth <= 0 || minHeight <= 0) return 0 to 0

    val width = ((minWidth + maxWidth) / 2f) * context.resources.displayMetrics.density
    val height = ((minHeight + maxHeight) / 2f) * context.resources.displayMetrics.density
    return width.toInt() to height.toInt()
  }
}