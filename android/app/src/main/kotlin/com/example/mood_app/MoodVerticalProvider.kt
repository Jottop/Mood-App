package com.example.mood_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * AppWidget "Tu día · Comparar burbujas (vertical)".
 *
 * Igual que [MoodComparisonProvider] pero dibuja la escena en RETRATO
 * (burbujas apiladas): el marco del escritorio es más largo que ancho
 * (appwidget_provider_vertical.xml, 1×2) y lee el MISMO cache compartido del
 * widget storage (colores + etiquetas de hoy), con layout fijo vertical. La
 * escena se ajusta al tamaño real del widget y se repinta al redimensionar.
 */
class MoodVerticalProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      WidgetComparisonRenderer.suggestTransposedSize(context, appWidgetManager, widgetId)
    }
    WidgetComparisonRenderer.render(context, appWidgetManager, appWidgetIds, widgetData, "v")
  }

  /** Al estirar/redimensionar el widget en el escritorio, repinta la escena a
   *  las nuevas dimensiones. */
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    WidgetComparisonRenderer.render(
        context,
        appWidgetManager,
        intArrayOf(appWidgetId),
        HomeWidgetPlugin.getData(context),
        "v",
    )
  }
}