-- Проверка ограничений целостности. Запускать после data.sql.
-- Каждая команда нарушает одно ограничение, PostgreSQL её отклоняет, и данные не меняются.
-- В DBeaver выполнять по одной команде (Ctrl+Enter), в psql — целиком: \i constraints_test.sql

-- 1. NOT NULL: пользователь без email.
-- ERROR: null value in column "email" of relation "users" violates not-null constraint
INSERT INTO users (password_hash, name)
VALUES ('$2b$12$hash', 'Без почты');

-- 2. UNIQUE: второй аккаунт на ту же почту.
-- ERROR: duplicate key value violates unique constraint "users_email_key"
INSERT INTO users (email, password_hash)
VALUES ('anna.petrova@mail.ru', '$2b$12$hash');

-- 3. Составной UNIQUE: тот же Google-аккаунт привязывают ко второму пользователю.
-- ERROR: duplicate key value violates unique constraint "users_oauth_key"
INSERT INTO users (email, oauth_provider, oauth_subject)
VALUES ('dmitry.second@gmail.com', 'google', '108234567890123456789');

-- 4. CHECK: у пользователя нет ни пароля, ни OAuth, войти невозможно.
-- ERROR: new row for relation "users" violates check constraint "users_has_login_method_chk"
INSERT INTO users (email, name)
VALUES ('nologin@mail.ru', 'Без входа');

-- 5. CHECK на два столбца: у ИП (ИНН из 12 цифр) не может быть КПП.
-- ERROR: new row for relation "companies" violates check constraint "companies_kpp_only_for_organizations_chk"
UPDATE companies
SET kpp = '027401001'
WHERE inn = '027412345678';

-- 6. UNIQUE, обеспечивающий связь 1:1: второй профиль курьера у того же пользователя.
-- ERROR: duplicate key value violates unique constraint "couriers_user_id_key"
INSERT INTO couriers (user_id, transport_type)
VALUES ((SELECT id FROM users WHERE email = 'timur.k@dostavka.ru'), 'bicycle');

-- 7. CHECK: у автомобиля стирают госномер.
-- ERROR: new row for relation "couriers" violates check constraint "couriers_car_has_plate_chk"
UPDATE couriers
SET vehicle_plate = NULL
WHERE vehicle_plate = 'А123ВС777';

-- 8. CHECK: пешему курьеру записывают госномер.
-- ERROR: new row for relation "couriers" violates check constraint "couriers_pedestrian_has_no_plate_chk"
UPDATE couriers
SET vehicle_plate = 'Е001КХ77'
WHERE user_id = (SELECT id FROM users WHERE email = 'timur.k@dostavka.ru');

-- 9. CHECK: широта за пределами [-90; 90].
-- ERROR: new row for relation "addresses" violates check constraint "addresses_lat_range_chk"
INSERT INTO addresses (city, street, house, lat, lng)
VALUES ('Москва', 'ул. Тверская', '1', 95.000000, 37.600000);

-- 10. CHECK на два столбца: у заказа сразу и адрес отправления, и ПВЗ отправления.
-- ERROR: new row for relation "orders" violates check constraint "orders_single_origin_chk"
UPDATE orders
SET origin_pickup_point_id = (SELECT id FROM pickup_points WHERE code = 'MSK-0001')
WHERE tracking_code = 'H2J5K8L1ZX';

-- 11. CHECK на два столбца: доставка одновременно до двери и в ПВЗ.
-- ERROR: new row for relation "orders" violates check constraint "orders_single_destination_chk"
INSERT INTO orders (
    tracking_code, user_id, origin_address_id, destination_address_id, destination_pickup_point_id,
    tariff, sender_name, sender_phone, recipient_name, recipient_phone, price
)
VALUES (
    'BAD0000001', (SELECT id FROM users WHERE email = 'anna.petrova@mail.ru'), 1, 2,
    (SELECT id FROM pickup_points WHERE code = 'MSK-0001'),
    'express', 'Анна', '+79161234567', 'Михаил Петров', '+79035550101', 590.00
);

-- 12. CHECK на два столбца: заказ перевели в «курьер забрал», а курьер не назначен.
-- ERROR: new row for relation "orders" violates check constraint "orders_courier_required_after_created_chk"
UPDATE orders
SET status = 'picked_up'
WHERE tracking_code = 'H2J5K8L1ZX';

-- 13. CHECK на два столбца: наложенный платёж в частном заказе (без компании).
-- ERROR: new row for relation "orders" violates check constraint "orders_cod_only_for_companies_chk"
UPDATE orders
SET cod_amount = 1000.00
WHERE tracking_code = 'K7Q2M9XP4A';

-- 14. CHECK: коробка с нулевой шириной.
-- ERROR: new row for relation "parcels" violates check constraint "parcels_dimensions_positive_chk"
INSERT INTO parcels (order_id, weight_g, length_cm, width_cm, height_cm)
VALUES ((SELECT id FROM orders WHERE tracking_code = 'K7Q2M9XP4A'), 500, 20, 0, 10);

-- 15. FOREIGN KEY: коробка ссылается на несуществующий заказ.
-- ERROR: insert or update on table "parcels" violates foreign key constraint "parcels_order_id_fkey"
INSERT INTO parcels (order_id, weight_g, length_cm, width_cm, height_cm)
VALUES (999, 500, 20, 15, 10);

-- Дополнительно: правила ON DELETE RESTRICT.

-- 16. Нельзя удалить компанию, у которой есть заказы.
-- ERROR: update or delete on table "companies" violates foreign key constraint "orders_company_id_fkey" on table "orders"
DELETE FROM companies
WHERE inn = '7701234567';

-- 17. Удаление пользователя-курьера каскадом удаляет его профиль курьера (CASCADE),
-- но на профиль ссылаются выполненные заказы (RESTRICT), поэтому удаление отклоняется целиком.
-- ERROR: update or delete on table "couriers" violates foreign key constraint "orders_courier_id_fkey" on table "orders"
DELETE FROM users
WHERE email = 'sergey.l@dostavka.ru';
