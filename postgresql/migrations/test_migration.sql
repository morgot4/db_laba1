-- 1. Новая колонка с DEFAULT и CHECK
BEGIN;
ALTER TABLE couriers
    ADD COLUMN rating NUMERIC(2, 1) NOT NULL DEFAULT 5.0,
    ADD CONSTRAINT couriers_rating_range_chk CHECK (rating BETWEEN 1 AND 5);
ROLLBACK;

-- 2. Обязательная колонка в заполненной таблице: добавить, заполнить, запретить NULL
BEGIN;
ALTER TABLE couriers ADD COLUMN hired_at DATE;
UPDATE couriers c
SET hired_at = u.created_at::date
FROM users u
WHERE u.id = c.user_id;
ALTER TABLE couriers ALTER COLUMN hired_at SET NOT NULL;
ROLLBACK;

-- 3. Смена типа с пересчётом значений и переименование: граммы -> килограммы
BEGIN;
ALTER TABLE parcels DROP CONSTRAINT parcels_weight_positive_chk;
ALTER TABLE parcels ALTER COLUMN weight_g TYPE NUMERIC(8, 3) USING weight_g / 1000.0;
ALTER TABLE parcels RENAME COLUMN weight_g TO weight_kg;
ALTER TABLE parcels ADD CONSTRAINT parcels_weight_positive_chk CHECK (weight_kg > 0);
ROLLBACK;

-- 4. Изменение ограничения: удалить и создать заново (смена ON DELETE)
BEGIN;
ALTER TABLE orders
    DROP CONSTRAINT orders_courier_id_fkey,
    ADD CONSTRAINT orders_courier_id_fkey
        FOREIGN KEY (courier_id) REFERENCES couriers (id) ON DELETE SET NULL;
ROLLBACK;

-- 5. ENUM: добавить и переименовать значение
BEGIN;
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'lost' AFTER 'delivered';
ALTER TYPE delivery_tariff RENAME VALUE 'same_day' TO 'standard';
ROLLBACK;

-- 6. Новая таблица с переносом существующих данных: история статусов
BEGIN;
CREATE TABLE order_status_history (
    order_id   BIGINT       NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    status     order_status NOT NULL,
    changed_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (order_id, changed_at)
);
INSERT INTO order_status_history (order_id, status, changed_at)
SELECT id, status, created_at
FROM orders;
ROLLBACK;
