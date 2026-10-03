BEGIN;

ALTER TABLE orders
    DROP CONSTRAINT IF EXISTS orders_cod_positive_chk,
    DROP CONSTRAINT IF EXISTS orders_cod_only_for_companies_chk,
    DROP COLUMN IF EXISTS cod_amount;

COMMIT;
