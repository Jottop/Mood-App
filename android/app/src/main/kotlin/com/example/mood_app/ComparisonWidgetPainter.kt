package com.example.mood_app

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import org.json.JSONArray
import org.json.JSONObject

/**
 * Dibuja en NATIVO (sin motor Flutter) la escena del widget de comparación
 * (de 1 a 3 burbujas, la 1.ª siempre "Yo", en horizontal o vertical), a
 * partir del cache que la app deja en el widget storage (JSON: etiqueta +
 * colores ARGB de cuerpo y aura). La geometría replica 1:1 la de
 * `MoodComparisonScenePainter` (Dart) a 2×, así el look es el mismo que
 * muestra el preview dentro de la app.
 *
 * Regla de rollover: si la fecha del cache no es HOY (el widget no pudo
 * refrescarse), las burbujas se dibujan VACÍAS conservando las etiquetas,
 * para no mentir con el estado de un día anterior.
 */
object ComparisonWidgetPainter {
  // Coordenadas de escena (dp), idénticas a las de Dart.
  private const val SCENE_W_HORIZONTAL = 360f
  private const val SCENE_H_HORIZONTAL = 220f
  private const val SCENE_W_VERTICAL = 220f
  private const val SCENE_H_VERTICAL = 420f
  private const val SCALE = 2f

  private const val INK = 0xFF2B3A4A.toInt()
  private const val TAG = "comparison_widget"

  private val RAINBOW = intArrayOf(
      0xFFFFB3C6.toInt(), 0xFFFFE29A.toInt(), 0xFFB9F0CB.toInt(),
      0xFFAED8FF.toInt(), 0xFFD3BBFF.toInt(), 0xFFFFB3C6.toInt(),
  )
  private val RAINBOW_STOPS = floatArrayOf(0f, 0.2f, 0.4f, 0.6f, 0.8f, 1f)

  /** Datos de una de las burbujas leídos del cache. */
  class Bubble(val label: String, val colors: IntArray, val aura: IntArray) {
    companion object {
      fun from(json: JSONObject): Bubble = Bubble(
          label = json.optString("l", "—"),
          colors = intArray(json.optJSONArray("c")),
          aura = intArray(json.optJSONArray("a")),
      )

      private fun intArray(array: JSONArray?): IntArray {
        if (array == null) return IntArray(0)
        val out = IntArray(array.length())
        for (i in out.indices) out[i] = array.optInt(i, 0)
        return out
      }
    }
  }

  /**
   * Genera la escena completa. Los valores provienen del widget storage de
   * home_widget (nombres de clave en `widget_cache_store.dart`).
   *
   * Devuelve `null` si no hay burbujas que dibujar o si algo falla en el
   * trazado: el llamador muestra el placeholder en vez de un lienzo en blanco
   * (un bitmap transparente sobre el degradado queda como "widget vacío").
   */
  fun draw(dateKey: String?, bubblesJson: String?, layoutJson: String?): Bitmap? {
    val vertical = layoutJson == "v"
    val sceneW = if (vertical) SCENE_W_VERTICAL else SCENE_W_HORIZONTAL
    val sceneH = if (vertical) SCENE_H_VERTICAL else SCENE_H_HORIZONTAL
    val bubbles = parseBubbles(bubblesJson)
    if (bubbles.isEmpty()) {
      Log.w(TAG, "No hay burbujas para dibujar; layout=$layoutJson json=${bubblesJson?.take(120)}")
      return null
    }

    val bitmap = try {
      Bitmap.createBitmap(
          (sceneW * SCALE).roundToInt(),
          (sceneH * SCALE).roundToInt(),
          Bitmap.Config.ARGB_8888,
      )
    } catch (_: Exception) {
      Log.w(TAG, "No se pudo crear el bitmap de la escena")
      return null
    }
    val canvas = Canvas(bitmap)
    canvas.scale(SCALE, SCALE)

    val isToday = dateKey == todayKey()
    try {
      if (vertical) {
        drawVertical(canvas, sceneW, sceneH, bubbles, isToday)
      } else {
        drawHorizontal(canvas, sceneW, sceneH, bubbles, isToday)
      }
    } catch (e: Exception) {
      Log.w(TAG, "El dibujo de la escena falló: ${e.message}")
      return null
    }
    Log.i(TAG, "Escena dibujada: ${bubbles.size} burbuja(s), layout=${if (vertical) 'v' else 'h'}, hoy=$isToday, date=$dateKey")
    return bitmap
  }

  private fun parseBubbles(json: String?): Array<Bubble> {
    if (json.isNullOrBlank()) return emptyArray()
    return try {
      val arr = JSONArray(json)
      val out = ArrayList<Bubble>(arr.length())
      for (i in 0 until arr.length()) {
        // Un miembro inválido se salta; no tumba al resto de la escena.
        val item = try {
          arr.optJSONObject(i) ?: continue
        } catch (_: Exception) {
          continue
        }
        out.add(Bubble.from(item))
      }
      out.toTypedArray()
    } catch (_: Exception) {
      Log.w(TAG, "No se pudo parsear el JSON de burbujas")
      emptyArray()
    }
  }

  private fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

  private fun drawHorizontal(
    canvas: Canvas,
    w: Float,
    h: Float,
    bubbles: Array<Bubble>,
    isToday: Boolean,
  ) {
    val n = bubbles.size
    if (n == 0) return
    val margin = w * 0.04f
    val gap = w * 0.033f
    val cellWidth = (w - 2 * margin - gap * (n - 1)) / n
    val labelFont = h * 0.10f
    val labelTop = h - (labelFont * 1.55f + 6f)
    val bubbleDiameter = min(w * 0.44f, cellWidth * 0.9f)
    val bubbleCenterY = h * 0.42f
    val labelOffset = labelTop + (labelFont * 1.55f - labelFont) / 2f

    for (i in 0 until n) {
      val cellLeft = margin + i * (cellWidth + gap)
      val centerX = cellLeft + cellWidth / 2f
      val bubble = bubbles[i]
      val colors = if (isToday) bubble.colors else IntArray(0)
      paintBubble(canvas, centerX, bubbleCenterY, bubbleDiameter, colors, bubble.aura)
      drawLabel(canvas, centerX, labelOffset, cellWidth, bubble.label, labelFont)
    }
  }

  private fun drawVertical(
    canvas: Canvas,
    w: Float,
    h: Float,
    bubbles: Array<Bubble>,
    isToday: Boolean,
  ) {
    val n = bubbles.size
    if (n == 0) return
    val margin = w * 0.04f
    val bubbleDiameter = w * 0.40f
    val labelFont = bubbleDiameter * 0.20f
    val labelBand = labelFont * 1.6f
    val rowStep = bubbleDiameter + labelBand
    val total = n * rowStep
    val startY = max(margin, (h - total) / 2f)
    val centerX = w / 2f

    for (i in 0 until n) {
      val y = startY + rowStep * i
      val bubble = bubbles[i]
      val colors = if (isToday) bubble.colors else IntArray(0)
      paintBubble(canvas, centerX, y + bubbleDiameter / 2f, bubbleDiameter, colors, bubble.aura)
      val labelTop = y + bubbleDiameter + (labelBand - labelFont) / 2f
      drawLabel(canvas, centerX, labelTop, w - 2 * margin, bubble.label, labelFont)
    }
  }

  // ──────────────────────────────────────────── burbuja ────────────────────────────────────────────

  private fun paintBubble(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    d: Float,
    colors: IntArray,
    aura: IntArray,
  ) {
    canvas.save()
    canvas.translate(cx - d / 2f, cy - d / 2f)

    // Cuerpo recortado al círculo (misma composición que `paintSphere`).
    canvas.save()
    canvas.clipPath(circlePath(d / 2f, d / 2f, d / 2f))
    if (colors.isEmpty()) {
      paintEmptyBody(canvas, d)
    } else if (colors.size == 1) {
      paintSingleFade(canvas, d, colors[0])
    } else {
      paintSectors(canvas, d, colors)
    }
    paintGlass(canvas, d)
    canvas.restore()

    // Aura fina por fuera del clip (anillos concéntricos del widget).
    paintSceneAura(canvas, d, aura)

    canvas.restore()
  }

  /** Burbuja vacía: translúcida, con el sheen de colores pastel (jabón). */
  private fun paintEmptyBody(canvas: Canvas, d: Float) {
    val centerX = d / 2f
    val centerY = d / 2f
    val r = d / 2f

    // Cuerpo: leve tinte de vidrio hacia el borde (look de jabón del widget
    // clásico, como en la app).
    canvas.drawCircle(centerX, centerY, r, paint {
      shader = RadialGradient(
          centerX, centerY, r,
          intArrayOf(white(0f), white(0.08f)),
          floatArrayOf(0.5f, 1f),
          Shader.TileMode.CLAMP,
      )
    })

    // Sheen con efecto de oleaje, como anillo difuminado entre dos contornos.
    val annulus = Path().apply {
      fillType = Path.FillType.EVEN_ODD
      addPath(wavyRing(centerX, centerY, d, r - d * 0.02f, 0f))
      addPath(wavyRing(centerX, centerY, d, r - d * 0.12f, PI.toFloat() / 3f))
    }
    canvas.drawPath(annulus, paint {
      style = Paint.Style.FILL
      maskFilter = BlurMaskFilter(d * 0.045f, BlurMaskFilter.Blur.NORMAL)
      shader = SweepGradient(
          centerX, centerY,
          RAINBOW.map { withAlpha(it, 0.55f) }.toIntArray(),
          RAINBOW_STOPS,
      )
    })

    // Borde fino y tenue.
    canvas.drawCircle(centerX, centerY, r - d * 0.015f, paint {
      style = Paint.Style.STROKE
      strokeWidth = d * 0.03f
      shader = SweepGradient(
          centerX, centerY,
          RAINBOW.map { withAlpha(it, 0.25f) }.toIntArray(),
          RAINBOW_STOPS,
      )
    })
  }

  /** Un solo estado: degradado suave y translúcido que se apaga hacia abajo. */
  private fun paintSingleFade(canvas: Canvas, d: Float, color: Int) {
    val centerX = d / 2f
    val topY = -d * 0.1f
    val radius = d * 1.3f
    canvas.drawCircle(centerX, topY, radius, paint {
      shader = RadialGradient(
          centerX, topY, radius,
          intArrayOf(
              color,
              withAlpha(color, 0.7f),
              withAlpha(color, 0.35f),
              withAlpha(color, 0f),
          ),
          floatArrayOf(0f, 0.4f, 0.72f, 1f),
          Shader.TileMode.CLAMP,
      )
    })
  }

  /** Dos o más estados: bandas iguales (1/N) en un degradado radial opaco. */
  private fun paintSectors(canvas: Canvas, d: Float, colors: IntArray) {
    val n = colors.size
    val centerX = d / 2f
    val topY = -d * 0.1f
    val bottomY = d
    val rhoMax = bottomY - topY

    val stops = FloatArray(n)
    for (i in 0 until n) {
      val rhoMid = (bottomY * (i + 0.5f) / n) - topY
      stops[i] = (rhoMid / rhoMax).coerceIn(0f, 1f)
    }
    canvas.drawCircle(centerX, topY, rhoMax, paint {
      shader = RadialGradient(
          centerX, topY, rhoMax,
          colors, stops,
          Shader.TileMode.CLAMP,
      )
    })
  }

  /** Efecto vidrio: brillos, medias lunas y borde translúcido. */
  private fun paintGlass(canvas: Canvas, d: Float) {
    // Blob principal arriba a la izquierda.
    drawGlassBlob(canvas, d * 0.25f, d * 0.25f, d * 0.35f, intArrayOf(white(0.43f), white(0.12f), white(0f)))
    // Blob secundario inferior derecho.
    drawGlassBlob(canvas, d * 0.81f, d * 0.83f, d * 0.35f, intArrayOf(white(0.58f), white(0.07f), white(0f)))

    // Reflejo superior en arco (media luna).
    paintCrescent(
        canvas, d,
        cx = d * 0.46f, cy = d * 0.39f, r0 = d * 0.25f,
        start = 3.3f, sweep = 1.6f,
        tStart = d * 0.09f, tEnd = d * 0.02f,
        opacity = 0.8f, blur = true,
    )
    // Reflejo inferior derecho (espejo del superior).
    paintCrescent(
        canvas, d,
        cx = d * 0.58f, cy = d * 0.62f, r0 = d * 0.25f,
        start = 6.74f, sweep = 1.1f,
        tStart = d * 0.048f, tEnd = d * 0.025f,
        opacity = 0.65f, blur = true,
    )

    }

  private fun drawGlassBlob(canvas: Canvas, cx: Float, cy: Float, radius: Float, colors: IntArray) {
    canvas.drawCircle(cx, cy, radius, paint {
      shader = RadialGradient(
          cx, cy, radius,
          colors,
          floatArrayOf(0f, 0.55f, 1f),
          Shader.TileMode.CLAMP,
      )
    })
  }

  /** Media luna (grosor variable a lo largo del arco), réplica de
   *  `MoodSphereCrescentPainter`. */
  private fun paintCrescent(
    canvas: Canvas,
    d: Float,
    cx: Float,
    cy: Float,
    r0: Float,
    start: Float,
    sweep: Float,
    tStart: Float,
    tEnd: Float,
    opacity: Float,
    blur: Boolean,
  ) {
    val a0 = start
    val a1 = start + sweep
    val steps = 20

    val capStartX = cx + (r0 + tStart / 2f) * cos(a0)
    val capStartY = cy + (r0 + tStart / 2f) * sin(a0)
    val capEndX = cx + (r0 + tEnd / 2f) * cos(a1)
    val capEndY = cy + (r0 + tEnd / 2f) * sin(a1)

    val path = Path().apply {
      moveTo(cx + r0 * cos(a0), cy + r0 * sin(a0))
      arcTo(oval(cx, cy, r0), radToDeg(a0), radToDeg(sweep), false)
      // Punta final: semicírculo que protruye hacia adelante.
      arcTo(oval(capEndX, capEndY, tEnd / 2f), radToDeg(a1 + PI.toFloat()), -180f, false)
      // Borde interior hacia atrás, con grosor variable tStart..tEnd.
      for (i in steps downTo 0) {
        val ang = a0 + (a1 - a0) * (i.toFloat() / steps)
        val rad = r0 + tStart + (tEnd - tStart) * (i.toFloat() / steps)
        lineTo(cx + rad * cos(ang), cy + rad * sin(ang))
      }
      // Punta inicial hasta el punto de partida.
      arcTo(oval(capStartX, capStartY, tStart / 2f), radToDeg(a0), -180f, false)
      close()
    }

    val p = paint {
      color = white(opacity)
      style = Paint.Style.FILL
    }
    if (blur) {
      p.maskFilter = BlurMaskFilter(d * 0.008f, BlurMaskFilter.Blur.NORMAL)
    }
    canvas.drawPath(path, p)
  }

  /** Anillos finos del widget por fuera de la burbuja (primeras 2 únicas),
   *  CONTIGUOS a la esfera: el primer anillo toca la burbuja y los anillos
   *  se tocan entre sí (el paso entre centros es el grosor del trazo). */
  private fun paintSceneAura(canvas: Canvas, d: Float, aura: IntArray) {
    val layers = linkedSetOf<Int>()
    for (c in aura) {
      if (layers.size >= 2) break
      layers.add(c)
    }
    if (layers.isEmpty()) return

    val baseR = d / 2f
    // Contiguo: el paso entre centros equivale al grosor del trazo, así el
    // primer anillo toca la esfera y los anillos se tocan entre sí.
    val step = d * 0.02f
    val stroke = d * 0.02f
    val shown = min(layers.size, 2)
    for ((i, auraColor) in layers.take(shown).withIndex()) {
      canvas.drawCircle(d / 2f, d / 2f, baseR + step * (i + 0.5f), paint {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        color = withAlpha(auraColor, 0.5f)
      })
    }
  }

  // ──────────────────────────────────────────── etiqueta ────────────────────────────────────────────

  private fun drawLabel(
    canvas: Canvas,
    cx: Float,
    top: Float,
    maxWidth: Float,
    text: String,
    fontSize: Float,
  ) {
    if (text.isEmpty()) return
    val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      color = INK
      textSize = fontSize
      typeface = Typeface.DEFAULT_BOLD
    }
    val layout = StaticLayout.Builder
        .obtain(text, 0, text.length, textPaint, maxWidth.toInt())
        .setAlignment(Layout.Alignment.ALIGN_CENTER)
        .setMaxLines(1)
        .setEllipsize(TextUtils.TruncateAt.END)
        .build()
    canvas.save()
    canvas.translate(cx - maxWidth / 2f, top)
    layout.draw(canvas)
    canvas.restore()
  }

  // ──────────────────────────────────────────── helpers ────────────────────────────────────────────

  private fun circlePath(cx: Float, cy: Float, r: Float): Path {
    return Path().apply { addOval(RectF(cx - r, cy - r, cx + r, cy + r), Path.Direction.CW) }
  }

  private fun oval(cx: Float, cy: Float, r: Float): RectF =
      RectF(cx - r, cy - r, cx + r, cy + r)

  private fun radToDeg(rad: Float): Float = rad * 180f / PI.toFloat()

  /** Contorno cerrado de una circunferencia con radio modulado por un seno. */
  private fun wavyRing(cx: Float, cy: Float, d: Float, midRadius: Float, phaseShift: Float): Path {
    val points = 84
    val lobes = 11
    val amplitude = d * 0.03f
    val path = Path()
    for (i in 0..points) {
      val theta = i / points.toFloat() * 2f * PI.toFloat()
      val r = midRadius + amplitude * sin(lobes * theta + phaseShift)
      val x = cx + r * cos(theta)
      val y = cy + r * sin(theta)
      if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    path.close()
    return path
  }

  private fun white(alphaFraction: Float): Int {
    val alpha = (alphaFraction.coerceIn(0f, 1f) * 255f).roundToInt()
    return 0xFFFFFF or (alpha shl 24)
  }

  private fun withAlpha(color: Int, alphaFraction: Float): Int {
    val alpha = (alphaFraction.coerceIn(0f, 1f) * 255f).roundToInt()
    return (color and 0x00FFFFFF) or (alpha shl 24)
  }

  private inline fun paint(block: Paint.() -> Unit): Paint {
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    p.block()
    return p
  }
}