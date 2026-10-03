package com.moneytrace.app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.moneytrace.app.MainActivity
import com.moneytrace.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 3 trend widget'ının (Aylık Değişim/Harcama/Maaş) ortak çizim mantığı. Alt sınıflar yalnız
 * [prefsId] (HomeWidgetService'in kaydettiği anahtar) ve renkleri sağlar; veri okuma, boyuta
 * duyarlı düzen seçimi ve bitmap render tek yerde (SQL'in Dart tarafında tekrar edilmemesi gibi,
 * burada da native tarafta tekrar edilmez).
 *
 * Boyuta duyarlı düzen: [AppWidgetManager.getAppWidgetOptions] ile mevcut hücre yüksekliği okunur;
 * 1 hücre (4x1/5x1, ~40dp) için [R.layout.widget_trend_compact] (yalnız özet metin), 2 hücre
 * (4x2/5x2, ~110dp) için [R.layout.widget_trend_expanded] (özet + 12 aylık mini grafik) kullanılır.
 */
abstract class BaseTrendWidgetProvider : HomeWidgetProvider() {

    abstract val prefsId: String
    abstract val accentColorRes: Int
    abstract val negativeColorRes: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = TrendWidgetData.from(widgetData, prefsId)
        appWidgetIds.forEach { widgetId ->
            updateOne(context, appWidgetManager, widgetId, data)
        }
    }

    private fun updateOne(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: TrendWidgetData?,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        // 1 hücre (~40dp) ile 2 hücre (~110dp) arası kabaca orta nokta. Launchera göre gerçek
        // hücre boyutu değişebileceği için bu bir YAKLAŞIM (kesin eşik yok) — bkz. görev raporu.
        val isExpanded = minHeightDp >= 75

        val layoutRes =
            if (isExpanded) R.layout.widget_trend_expanded else R.layout.widget_trend_compact
        val views = RemoteViews(context.packageName, layoutRes)

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        if (data == null || !data.hasData) {
            views.setTextViewText(R.id.widget_title, data?.title ?: "")
            views.setTextViewText(R.id.widget_summary, data?.noDataText ?: "")
            views.setViewVisibility(R.id.widget_delta, View.GONE)
            if (isExpanded) {
                views.setViewVisibility(R.id.widget_chart, View.GONE)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        views.setTextViewText(R.id.widget_title, data.title)
        views.setTextViewText(R.id.widget_summary, data.currentLabel)
        if (data.deltaLabel != null) {
            views.setViewVisibility(R.id.widget_delta, View.VISIBLE)
            views.setTextViewText(R.id.widget_delta, data.deltaLabel)
        } else {
            views.setViewVisibility(R.id.widget_delta, View.GONE)
        }

        if (isExpanded) {
            renderChart(context, views, options, data)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderChart(
        context: Context,
        views: RemoteViews,
        options: android.os.Bundle,
        data: TrendWidgetData,
    ) {
        val density = context.resources.displayMetrics.density
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            .takeIf { it > 0 } ?: 250
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            .takeIf { it > 0 } ?: 110
        // Başlık + özet satırı için ayrılan yaklaşık pay düşülür; kalan grafiğe gider.
        val chartHeightDp = (minHeightDp - 44).coerceAtLeast(40)
        val widthPx = (widthDp * density).toInt()
        val heightPx = (chartHeightDp * density).toInt()

        val bitmap = SparklineRenderer.render(
            widthPx = widthPx,
            heightPx = heightPx,
            ratios = data.ratios,
            accentColor = context.getColor(accentColorRes),
            negativeColor = context.getColor(negativeColorRes),
            months = data.months,
            drawMonthLabels = true,
            density = density,
        )

        if (bitmap != null) {
            views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
            views.setImageViewBitmap(R.id.widget_chart, bitmap)
        } else {
            views.setViewVisibility(R.id.widget_chart, View.GONE)
        }
    }
}
