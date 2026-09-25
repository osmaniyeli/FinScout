-- assets/sql/v4_payslip_wage.sql
-- v4: Bordro birim ücreti (saatlik/aylık "Ücreti" satırı). Zam tespiti brüt yerine bu ücretin
-- değişimine bakar. Yalnız bordro maaş kaydında dolu; okunamayan/eski kayıtlarda NULL.

ALTER TABLE transactions ADD COLUMN base_wage_cents INTEGER;
