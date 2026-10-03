package com.moneytrace.app.widget

import android.content.SharedPreferences
import org.json.JSONObject

/**
 * [HomeWidgetService] (Dart) tarafından `HomeWidget.saveWidgetData` ile kaydedilen, 3 trend
 * widget'ının (Aylık Değişim/Harcama/Maaş) ortak JSON yükü. Para biçimi tamamen Flutter tarafında
 * ([CurrencyNormalizer]) üretilir; burada yalnız HAZIR string'ler okunur, native tarafta ayrıca
 * bir biçimlendirme mantığı YOK.
 */
data class TrendWidgetData(
    val title: String,
    val hasData: Boolean,
    val months: List<String> = emptyList(),
    val cents: List<Long> = emptyList(),
    /** -1..1 aralığında (mutlak en büyük aya göre); net değişim gibi eksi değer alabilen
     * serilerde negatif olabilir — bkz. TransactionRepository._mapMonthlyRows (Dart). */
    val ratios: List<Double> = emptyList(),
    val currentLabel: String = "",
    val currentMonth: String = "",
    val deltaLabel: String? = null,
    val hideAmounts: Boolean = false,
    val noDataText: String = "",
) {
    companion object {
        /** [prefsId]: HomeWidgetService.saveWidgetData'ya verilen kimlik (örn. "widget_monthly_change"). */
        fun from(widgetData: SharedPreferences, prefsId: String): TrendWidgetData? {
            val raw = widgetData.getString(prefsId, null) ?: return null
            return try {
                val json = JSONObject(raw)
                val hasData = json.optBoolean("hasData", false)
                if (!hasData) {
                    return TrendWidgetData(
                        title = json.optString("title", ""),
                        hasData = false,
                        noDataText = json.optString("noDataText", ""),
                    )
                }
                val monthsArr = json.optJSONArray("months")
                val centsArr = json.optJSONArray("cents")
                val ratiosArr = json.optJSONArray("ratios")
                val months = (0 until (monthsArr?.length() ?: 0)).map { monthsArr!!.getString(it) }
                val cents = (0 until (centsArr?.length() ?: 0)).map { centsArr!!.getLong(it) }
                val ratios = (0 until (ratiosArr?.length() ?: 0)).map { ratiosArr!!.getDouble(it) }
                val delta = if (json.has("deltaLabel") && !json.isNull("deltaLabel")) {
                    json.optString("deltaLabel")
                } else {
                    null
                }
                TrendWidgetData(
                    title = json.optString("title", ""),
                    hasData = true,
                    months = months,
                    cents = cents,
                    ratios = ratios,
                    currentLabel = json.optString("currentLabel", ""),
                    currentMonth = json.optString("currentMonth", ""),
                    deltaLabel = delta,
                    hideAmounts = json.optBoolean("hideAmounts", false),
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}
