package com.moneytrace.app.widget

import com.moneytrace.app.R

/** "Aylık Harcama" widget'ı: ay ay toplam gider. Veri: HomeWidgetService (Dart), prefsId
 * "widget_monthly_expense" (bkz. TransactionRepository.getMonthlyTrendsAnalysis). */
class MonthlyExpenseWidgetProvider : BaseTrendWidgetProvider() {
    override val prefsId = "widget_monthly_expense"
    override val accentColorRes = R.color.widget_accent_expense
    override val negativeColorRes = R.color.widget_accent_negative
}
