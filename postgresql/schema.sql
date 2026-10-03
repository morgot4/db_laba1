CREATE TYPE oauth_provider AS ENUM ('google', 'yandex', 'vk', 'apple');
CREATE TYPE transport_type AS ENUM ('foot', 'bicycle', 'scooter', 'car');
CREATE TYPE pickup_point_type AS ENUM ('pvz', 'parcel_locker');
CREATE TYPE delivery_tariff AS ENUM ('express', 'same_day');
CREATE TYPE order_status AS ENUM (
    'created',
    'dropped_off',
    'courier_assigned',
    'picked_up',
    'ready_for_pickup',
    'delivered',
    'cancelled',
    'returned'
);

CREATE TABLE companies (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    inn  VARCHAR(12)  NOT NULL UNIQUE,
    kpp  VARCHAR(9),
    CONSTRAINT companies_kpp_only_for_organizations_chk CHECK ((length(inn) = 10) = (kpp IS NOT NULL))
);

CREATE TABLE users (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_id     BIGINT         REFERENCES companies (id) ON DELETE SET NULL,
    email          VARCHAR(254)   NOT NULL UNIQUE,
    phone          VARCHAR(16)    UNIQUE,
    password_hash  TEXT,
    oauth_provider oauth_provider,
    oauth_subject  VARCHAR(255),
    name           VARCHAR(100),
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT users_oauth_key UNIQUE (oauth_provider, oauth_subject),
    CONSTRAINT users_has_login_method_chk CHECK (password_hash IS NOT NULL OR oauth_subject IS NOT NULL)
);

CREATE TABLE couriers (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        BIGINT         NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    transport_type transport_type NOT NULL,
    vehicle_plate  VARCHAR(12),
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    CONSTRAINT couriers_car_has_plate_chk CHECK (transport_type <> 'car' OR vehicle_plate IS NOT NULL),
    CONSTRAINT couriers_pedestrian_has_no_plate_chk CHECK (transport_type <> 'foot' OR vehicle_plate IS NULL)
);

CREATE TABLE addresses (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city          VARCHAR(100)  NOT NULL,
    street        VARCHAR(255)  NOT NULL,
    house         VARCHAR(20)   NOT NULL,
    apartment     VARCHAR(10),
    entrance      SMALLINT,
    floor         SMALLINT,
    intercom_code VARCHAR(20),
    lat      NUMERIC(8, 6) NOT NULL,
    lng     NUMERIC(9, 6) NOT NULL,
    CONSTRAINT addresses_entrance_positive_chk CHECK (entrance > 0),
    CONSTRAINT addresses_lat_range_chk CHECK (lat BETWEEN -90 AND 90),
    CONSTRAINT addresses_lng_range_chk CHECK (lng BETWEEN -180 AND 180)
);

CREATE TABLE pickup_points (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         VARCHAR(20)       NOT NULL UNIQUE,
    type         pickup_point_type NOT NULL,
    address_id   BIGINT            NOT NULL REFERENCES addresses (id) ON DELETE RESTRICT,
    max_weight_g INTEGER           NOT NULL,
    is_active    BOOLEAN           NOT NULL DEFAULT TRUE,
    CONSTRAINT pickup_points_max_weight_positive_chk CHECK (max_weight_g > 0)
);

CREATE TABLE orders (
    id                          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tracking_code               VARCHAR(12)     NOT NULL UNIQUE,
    user_id                     BIGINT          NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    company_id                  BIGINT          REFERENCES companies (id) ON DELETE RESTRICT,
    courier_id                  BIGINT          REFERENCES couriers (id) ON DELETE RESTRICT,
    origin_address_id           BIGINT          REFERENCES addresses (id) ON DELETE RESTRICT,
    origin_pickup_point_id      INTEGER         REFERENCES pickup_points (id) ON DELETE RESTRICT,
    destination_address_id      BIGINT          REFERENCES addresses (id) ON DELETE RESTRICT,
    destination_pickup_point_id INTEGER         REFERENCES pickup_points (id) ON DELETE RESTRICT,
    tariff                      delivery_tariff NOT NULL,
    estimated_weight_g          INTEGER,
    status                      order_status    NOT NULL DEFAULT 'created',
    sender_name                 VARCHAR(100)    NOT NULL,
    sender_phone                VARCHAR(16)     NOT NULL,
    recipient_name              VARCHAR(100)    NOT NULL,
    recipient_phone             VARCHAR(16)     NOT NULL,
    price                       NUMERIC(10, 2)  NOT NULL,
    cod_amount                  NUMERIC(10, 2),
    comment                     TEXT,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT orders_single_origin_chk CHECK (num_nonnulls(origin_address_id, origin_pickup_point_id) = 1),
    CONSTRAINT orders_single_destination_chk CHECK (num_nonnulls(destination_address_id, destination_pickup_point_id) = 1),
    CONSTRAINT orders_courier_required_after_created_chk CHECK (courier_id IS NOT NULL OR status IN ('created', 'dropped_off', 'cancelled')),
    CONSTRAINT orders_estimated_weight_positive_chk CHECK (estimated_weight_g > 0),
    CONSTRAINT orders_price_non_negative_chk CHECK (price >= 0),
    CONSTRAINT orders_cod_positive_chk CHECK (cod_amount > 0),
    CONSTRAINT orders_cod_only_for_companies_chk CHECK (cod_amount IS NULL OR company_id IS NOT NULL)
);

CREATE TABLE parcels (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id       BIGINT         NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    weight_g       INTEGER        NOT NULL,
    length_cm      SMALLINT       NOT NULL,
    width_cm       SMALLINT       NOT NULL,
    height_cm      SMALLINT       NOT NULL,
    declared_value NUMERIC(12, 2) NOT NULL DEFAULT 0,
    CONSTRAINT parcels_weight_positive_chk CHECK (weight_g > 0),
    CONSTRAINT parcels_dimensions_positive_chk CHECK (length_cm > 0 AND width_cm > 0 AND height_cm > 0),
    CONSTRAINT parcels_declared_value_non_negative_chk CHECK (declared_value >= 0)
);
