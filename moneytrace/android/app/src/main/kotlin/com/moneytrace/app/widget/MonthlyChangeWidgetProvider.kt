package com.moneytrace.app.widget

import com.moneytrace.app.R

/** "Aylık Değişim" widget'ı: ay ay net değişim (gelir − gider). Veri: HomeWidgetService (Dart),
 * prefsId "widget_monthly_change" (bkz. TransactionRepository.getMonthlyNetChangeTrends). */
class MonthlyChangeWidgetProvider : BaseTrendWidgetProvider() {
    override val prefsId = "widget_monthly_change"
    override val accentColorRes = R.color.widget_accent_change
    override val negativeColorRes = R.color.widget_accent_negative
}
