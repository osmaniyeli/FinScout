package com.moneytrace.app.widget

import com.moneytrace.app.R

/** "Aylık Maaş" widget'ı: ay ay toplam gelir/maaş (tx_kind = SALARY). Veri: HomeWidgetService
 * (Dart), prefsId "widget_monthly_salary" (bkz. TransactionRepository.getMonthlySalaryTrends). */
class MonthlySalaryWidgetProvider : BaseTrendWidgetProvider() {
    override val prefsId = "widget_monthly_salary"
    override val accentColorRes = R.color.widget_accent_salary
    override val negativeColorRes = R.color.widget_accent_negative
}
