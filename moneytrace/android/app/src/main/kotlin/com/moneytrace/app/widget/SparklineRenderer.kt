package com.moneytrace.app.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/**
 * 12 aylık trend verisini küçük bir sparkline/bar-chart bitmap'ine çizer. RemoteViews karmaşık
 * grafik widget'larını (fl_chart vb.) desteklemediği için 4x2/5x2 boyutlardaki tam grafik,
 * [android.widget.RemoteViews.setImageViewBitmap] ile gösterilen bu bitmap üzerinden sağlanır
 * (bkz. BaseTrendWidgetProvider).
 */
object SparklineRenderer {

    /**
     * [ratios]: -1..1 aralığında (negatif olabilir, bkz. TrendWidgetData.ratios). Tüm değerler
     * negatif değilse çubuklar alttan yukarı çizilir (harcama/maaş); herhangi biri negatifse
     * (net değişim) sıfır çizgisi ortaya alınır, pozitifler yukarı/accent, negatifler aşağı/kırmızı.
     * [drawMonthLabels]: yalnız 4x2/5x2 (geniş) düzende true — 3 ayda bir + son ay etiketi basılır.
     */
    fun render(
        widthPx: Int,
        heightPx: Int,
        ratios: List<Double>,
        accentColor: Int,
        negativeColor: Int,
        months: List<String>,
        drawMonthLabels: Boolean,
        density: Float,
    ): Bitmap? {
        if (widthPx <= 0 || heightPx <= 0 || ratios.isEmpty()) return null

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val labelHeightPx = if (drawMonthLabels) (12 * density) else 0f
        val chartHeight = (heightPx - labelHeightPx).coerceAtLeast(4f * density)
        val hasNegative = ratios.any { it < -0.02 }
        val zeroY = if (hasNegative) chartHeight / 2f else chartHeight
        val maxBarHeight = if (hasNegative) chartHeight / 2f else chartHeight

        val barCount = ratios.size
        val gapPx = 2 * density
        val totalGap = gapPx * (barCount - 1).coerceAtLeast(0)
        val barWidth = ((widthPx - totalGap) / barCount).coerceAtLeast(1f)
        val cornerRadius = (barWidth * 0.3f).coerceAtMost(4f * density)

        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(
                160,
                Color.red(accentColor),
                Color.green(accentColor),
                Color.blue(accentColor),
            )
            textSize = 9f * density
            textAlign = Paint.Align.CENTER
        }

        for (i in 0 until barCount) {
            val ratio = ratios[i]
            val barH = (kotlin.math.abs(ratio).toFloat() * maxBarHeight).coerceAtLeast(2f * density)
            val x = i * (barWidth + gapPx)
            barPaint.color = if (ratio < 0) negativeColor else accentColor

            val top: Float
            val bottom: Float
            if (ratio < 0) {
                top = zeroY
                bottom = (zeroY + barH).coerceAtMost(chartHeight)
            } else {
                bottom = zeroY
                top = (zeroY - barH).coerceAtLeast(0f)
            }
            canvas.drawRoundRect(RectF(x, top, x + barWidth, bottom), cornerRadius, cornerRadius, barPaint)

            if (drawMonthLabels && (i == barCount - 1 || i % 3 == 0)) {
                canvas.drawText(
                    months.getOrElse(i) { "" },
                    x + barWidth / 2f,
                    heightPx.toFloat() - 2f * density,
                    labelPaint,
                )
            }
        }

        return bitmap
    }
}
