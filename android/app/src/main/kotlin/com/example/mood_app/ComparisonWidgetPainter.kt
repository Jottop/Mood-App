package com.example.mood_app

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import org.json.JSONObject

/**
 * Dibuja en NATIVO (sin motor Flutter) la escena del widget de comparación
 * "mía vs. amigo", a partir del cache que la app deja en el widget storage
 * (JSON: etiqueta + colores ARGB de cuerpo y aura). La geometría replica 1:1
 * la de `MoodComparisonScenePainter` (Dart): horizontal 360×220 a 2×
 * (720×440) y vertical 220×360 a 2× (440×720 — el horizontal girado), así el
 * look es el mismo que muestra el preview dentro de la app.
 *
 * Regla de rollover: si la fecha del cache no es HOY (el widget no pudo
 * refrescarse), ambas burbujas se dibujan VACÍAS conservando las etiquetas,
 * para no mentir con el estado de un día anterior.
 */
object ComparisonWidgetPainter {
  const val WIDTH = 720
  const val HEIGHT = 440

  private const val VERTICAL_WIDTH = 440
  private const val VERTICAL_HEIGHT = 720

  private const val INK = 0xFF2B3A4A.toInt()

  private val RAINBOW = intArrayOf(
      0xFFFFB3C6.toInt(), 0xFFFFE29A.toInt(), 0xFFB9F0CB.toInt(),
      0xFFAED8FF.toInt(), 0xFFD3BBFF.toInt(), 0xFFFFB3C6.toInt(),
  )
  private val RAINBOW_STOPS = floatArrayOf(0f, 0.2f, 0.4f, 0.6f, 0.8f, 1f)

  /** Datos de una de las dos burbujas leídos del cache. */
  class Bubble(val label: String, val colors: IntArray, val aura: IntArray) {
    companion object {
      fun from(json: String?): Bubble? {
        if (json.isNullOrBlank()) return null
        return try {
          val root = JSONObject(json)
          Bubble(
              label = root.optString("l", "—"),
              colors = intArray(root.optJSONArray("c")),
              aura = intArray(root.optJSONArray("a")),
          )
        } catch (_: Exception) {
          null
        }
      }

      private fun intArray(array: org.json.JSONArray?): IntArray {
        if (array == null) return IntArray(0)
        val out = IntArray(array.length())
        for (i in out.indices) out[i] = array.getInt(i)
        return out
      }
    }
  }

  /**
   * Genera la escena completa. Los valores provienen del widget storage de
   * home_widget (nombres de clave en `widget_cache_store.dart`); `layoutJson`
   * vale "v" para vertical (apiladas) o cualquier otra cosa/nulo para
   * horizontal (lado a lado). `targetWidth`/`targetHeight` (px) permiten
   * pintar EXACTAMENTE el marco real que el launcher le dio al widget: toda la
   * geometría se deriva del lado corto, así el mismo diseño se adapta a
   * cualquier tamaño sin espacios vacíos (con 0/0 usa los tamaños por defecto).
   */
  fun draw(
    dateKey: String?,
    mineJson: String?,
    friendJson: String?,
    layoutJson: String?,
    targetWidth: Int = 0,
    targetHeight: Int = 0,
  ): Bitmap {
    val mine = Bubble.from(mineJson)
    val friend = Bubble.from(friendJson)

    val isToday = dateKey == todayKey()
    val mineColors = if (isToday) mine?.colors ?: IntArray(0) else IntArray(0)
    val friendColors = if (isToday) friend?.colors ?: IntArray(0) else IntArray(0)
    val mineAura = mine?.aura ?: IntArray(0)
    val friendAura = friend?.aura ?: IntArray(0)
    val mineLabel = mine?.label ?: "Yo"
    val friendLabel = friend?.label ?: "—"

    return if (layoutJson == "v") {
      drawVertical(
          mineColors, friendColors, mineAura, friendAura, mineLabel, friendLabel,
          if (targetWidth > 0) targetWidth else VERTICAL_WIDTH,
          if (targetHeight > 0) targetHeight else VERTICAL_HEIGHT,
      )
    } else {
      drawHorizontal(
          mineColors, friendColors, mineAura, friendAura, mineLabel, friendLabel,
          if (targetWidth > 0) targetWidth else WIDTH,
          if (targetHeight > 0) targetHeight else HEIGHT,
      )
    }
  }

  private fun drawHorizontal(
    mineColors: IntArray,
    friendColors: IntArray,
    mineAura: IntArray,
    friendAura: IntArray,
    mineLabel: String,
    friendLabel: String,
    width: Int = WIDTH,
    height: Int = HEIGHT,
  ): Bitmap {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    paintBackground(canvas, width, height)

    val shortSide = min(width, height)
    val margin = shortSide * 0.065f
    val gap = shortSide * 0.054f
    val cellWidth = (width - 2 * margin - gap) / 2f

    var labelFont = shortSide * 0.10f
    val labelBand = labelFont * 1.55f
    var bubbleDiameter = min(shortSide * 0.72f, cellWidth)

    // Ajuste por altura: el bloque (burbuja + hueco + etiqueta) debe caber en
    // el lienzo con sus márgenes; si no, TODO se escala de forma uniforme.
    val availableVert = height - 2 * margin
    val block = bubbleDiameter + labelBand + labelFont * 0.25f
    if (block > availableVert) {
      val fit = availableVert / block
      bubbleDiameter *= fit
      labelFont *= fit
    }

    val gapToLabel = labelFont * 0.25f
    val bubbleCenterY = height - margin - labelFont * 1.55f - gapToLabel - bubbleDiameter / 2f
    val labelTop = bubbleCenterY + bubbleDiameter / 2f + gapToLabel

    val leftCenterX = margin + cellWidth / 2f
    val rightCenterX = margin + cellWidth + gap + cellWidth / 2f

    paintBubble(canvas, leftCenterX, bubbleCenterY, bubbleDiameter, mineColors, mineAura)
    paintBubble(canvas, rightCenterX, bubbleCenterY, bubbleDiameter, friendColors, friendAura)

    drawLabel(canvas, leftCenterX, labelTop, cellWidth, mineLabel, labelFont)
    drawLabel(canvas, rightCenterX, labelTop, cellWidth, friendLabel, labelFont)

    return bitmap
  }

  /** Escena en retrato (el horizontal girado): burbujas apiladas, la mía
   *  arriba y la del amigo abajo, cada una con su etiqueta. Las burbujas y
   *  etiquetas derivan del lado corto y, si dos filas apiladas no alcanzan a
   *  caber a tamaño completo, TODO el bloque se escala de forma uniforme para
   *  caber con los márgenes. */
  private fun drawVertical(
    mineColors: IntArray,
    friendColors: IntArray,
    mineAura: IntArray,
    friendAura: IntArray,
    mineLabel: String,
    friendLabel: String,
    width: Int = VERTICAL_WIDTH,
    height: Int = VERTICAL_HEIGHT,
  ): Bitmap {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    paintBackground(canvas, width, height)

    val shortSide = min(width, height)
    val margin = shortSide * 0.04f
    var bubbleDiameter = shortSide * 0.72f
    var labelFont = shortSide * 0.10f
    val labelBand = labelFont * 1.6f
    val rowGap = shortSide * 0.08f
    var rowStep = bubbleDiameter + labelBand + rowGap
    var total = 2f * rowStep
    val available = height - 2 * margin
    if (total > available) {
      val fit = available / total
      bubbleDiameter *= fit
      labelFont *= fit
      rowStep *= fit
      total *= fit
    }
    val startY = max(margin, (height - total) / 2f)
    val centerX = width / 2f
    val labelMaxWidth = width - 2 * margin

    paintBubble(canvas, centerX, startY + bubbleDiameter / 2f, bubbleDiameter, mineColors, mineAura)
    drawLabel(canvas, centerX, startY + bubbleDiameter + (labelBand - labelFont) / 2f, labelMaxWidth, mineLabel, labelFont)

    val friendY = startY + rowStep
    paintBubble(canvas, centerX, friendY + bubbleDiameter / 2f, bubbleDiameter, friendColors, friendAura)
    drawLabel(canvas, centerX, friendY + bubbleDiameter + (labelBand - labelFont) / 2f, labelMaxWidth, friendLabel, labelFont)

    return bitmap
  }

  // ──────────────────────────────────────────── fondo ────────────────────────────────────────────

  /** Pinta la tarjeta redondeada de fondo (grada la escena): el degradado
   *  clásico de `widget_bg.xml` (lavanda arriba → celeste abajo). */
  private fun paintBackground(canvas: Canvas, width: Int, height: Int) {
    val shortSide = min(width, height)
    // 28dp de radio a la escala de diseño (lado corto 220dp) → proporcional.
    val radius = shortSide * 28f / 220f
    val clip = Path().apply {
      addRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, Path.Direction.CW)
    }
    canvas.save()
    canvas.clipPath(clip)
    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint {
      shader = LinearGradient(
          0f, 0f, 0f, height.toFloat(),
          intArrayOf(0xFFEBDFF7.toInt(), 0xFFD9E9FB.toInt()),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
      )
    })
    canvas.restore()
  }

  private fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

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

    // Cuerpo: leve tinte de vidrio hacia el borde.
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