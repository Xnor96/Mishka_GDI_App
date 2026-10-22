-- ddl_sqlite.sql
-- Esquema SQLite para Mishka GDI (single-device, en tablet)
-- Migrado desde ddl.sql (Postgres) — septiembre 2026
--
-- Cambios respecto a la versión Postgres:
--   - Se eliminan las tablas de tienda virtual (clientes, pedidos, etc.).
--   - Se elimina la columna productos.disponible_web (solo aplicaba a tienda web).
--   - SERIAL          → INTEGER PRIMARY KEY AUTOINCREMENT
--   - TIMESTAMP       → DATETIME
--   - BOOLEAN         → INTEGER (0=false, 1=true)
--   - VARCHAR(n)      → TEXT (SQLite no aplica el límite)
--   - DECIMAL(x,y)    → REAL
--   - Los triggers de fecha_actualizacion usan WHEN para evitar recursión
--   - GENERATED ALWAYS AS ... STORED requiere SQLite 3.31+ (Android moderno lo tiene)

PRAGMA foreign_keys = ON;

-- =============================================
-- TABLA: usuarios
-- =============================================
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario          INTEGER PRIMARY KEY AUTOINCREMENT,
    username            TEXT     NOT NULL UNIQUE,
    email               TEXT     NOT NULL UNIQUE,
    password_hash       TEXT     NOT NULL,
    nombre              TEXT     NOT NULL DEFAULT '',
    rol                 TEXT     NOT NULL DEFAULT 'empleado',  -- admin, empleado
    activo              INTEGER  NOT NULL DEFAULT 1,           -- 0/1
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (activo IN (0, 1)),
    CHECK (rol IN ('admin', 'empleado'))
);

-- =============================================
-- TABLA: categorias
-- =============================================
CREATE TABLE IF NOT EXISTS categorias (
    id_categoria        INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT     NOT NULL UNIQUE,
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- TABLA: productos
-- =============================================
CREATE TABLE IF NOT EXISTS productos (
    id_producto         INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo              TEXT     NOT NULL UNIQUE,
    nombre              TEXT     NOT NULL,
    id_categoria        INTEGER  REFERENCES categorias(id_categoria) ON DELETE SET NULL,
    unidad_medida       TEXT     NOT NULL DEFAULT 'UNIDAD',
    precio_unitario     REAL     NOT NULL DEFAULT 0.0,
    stock_actual        INTEGER  NOT NULL DEFAULT 0,
    stock_inicial       INTEGER  NOT NULL DEFAULT 0,
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (precio_unitario >= 0),
    CHECK (stock_inicial   >= 0)
);

-- =============================================
-- TABLA: entradas_productos
-- =============================================
CREATE TABLE IF NOT EXISTS entradas_productos (
    id_entrada          INTEGER PRIMARY KEY AUTOINCREMENT,
    id_producto         INTEGER  NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    fecha_entrada       DATE     NOT NULL,
    cantidad            INTEGER  NOT NULL DEFAULT 0,
    precio_unitario     REAL     DEFAULT NULL,
    observaciones       TEXT     NOT NULL DEFAULT '',
    usuario_registro    TEXT     NOT NULL DEFAULT 'sistema',
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (cantidad > 0),
    CHECK (precio_unitario >= 0 OR precio_unitario IS NULL)
);

-- =============================================
-- TABLA: ventas
-- (cabecera de una venta multi-ítem — octubre 2026)
-- Una venta tiene UN lugar, UN tipo de pago, UNA fecha, UN total,
-- y N líneas (salidas_productos con el mismo id_venta).
-- =============================================
CREATE TABLE IF NOT EXISTS ventas (
    id_venta            INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha_venta         DATE     NOT NULL,
    lugar_venta         TEXT     NOT NULL DEFAULT '',    -- ALL BAZAR, PINKSTORE, PERSONAL, VERBENA, etc.
    tipo_pago           TEXT     NOT NULL DEFAULT '',    -- EFECTIVO, TRANSFERENCIA, CLIP, etc.
    total               REAL     NOT NULL DEFAULT 0.0,   -- suma de los subtotales de las líneas
    observaciones       TEXT     NOT NULL DEFAULT '',
    usuario_registro    TEXT     NOT NULL DEFAULT 'sistema',
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (total >= 0)
);

-- =============================================
-- TABLA: salidas_productos
-- (líneas de una venta — cada fila es un producto dentro de una venta)
-- Campos duplicados (fecha_salida, lugar_venta, tipo_pago) se mantienen por
-- compatibilidad con reportes/queries existentes; para una venta multi-ítem
-- son una copia de los campos del header `ventas`.
-- =============================================
CREATE TABLE IF NOT EXISTS salidas_productos (
    id_salida           INTEGER PRIMARY KEY AUTOINCREMENT,
    id_venta            INTEGER  REFERENCES ventas(id_venta) ON DELETE CASCADE,
    id_producto         INTEGER  NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    fecha_salida        DATE     NOT NULL,
    cantidad            INTEGER  NOT NULL DEFAULT 0,
    precio_venta        REAL     NOT NULL DEFAULT 0.0,   -- Precio unitario al vender
    descuento           REAL     NOT NULL DEFAULT 0.0,   -- Legacy — no se usa en nuevas ventas
    total               REAL     NOT NULL DEFAULT 0.0,   -- precio_venta * cantidad
    lugar_venta         TEXT     NOT NULL DEFAULT '',    -- Copia del header
    tipo_pago           TEXT     NOT NULL DEFAULT '',    -- Copia del header
    observaciones       TEXT     NOT NULL DEFAULT '',
    usuario_registro    TEXT     NOT NULL DEFAULT 'sistema',
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (cantidad     > 0),
    CHECK (precio_venta >= 0),
    CHECK (descuento    >= 0),
    CHECK (total        >= 0)
);

-- =============================================
-- TABLA: control_diario
-- =============================================
CREATE TABLE IF NOT EXISTS control_diario (
    id_control          INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha               DATE     NOT NULL,
    descripcion         TEXT     NOT NULL,
    monto_entrada       REAL     NOT NULL DEFAULT 0.0,
    monto_salida        REAL     NOT NULL DEFAULT 0.0,
    observaciones       TEXT     NOT NULL DEFAULT '',
    es_verbena          INTEGER  NOT NULL DEFAULT 0,     -- 0/1
    usuario_registro    TEXT     NOT NULL DEFAULT 'sistema',
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (monto_entrada >= 0),
    CHECK (monto_salida  >= 0),
    CHECK (es_verbena IN (0, 1))
);

-- =============================================
-- TABLA: resumen_mensual
-- Columna calculada 'balance' — requiere SQLite 3.31+
-- =============================================
CREATE TABLE IF NOT EXISTS resumen_mensual (
    id_resumen              INTEGER PRIMARY KEY AUTOINCREMENT,
    mes                     INTEGER  NOT NULL CHECK (mes BETWEEN 1 AND 12),
    anio                    INTEGER  NOT NULL,
    total_ingresos          REAL     NOT NULL DEFAULT 0.0,
    total_gastos_fijos      REAL     NOT NULL DEFAULT 0.0,
    total_gastos_variables  REAL     NOT NULL DEFAULT 0.0,
    balance                 REAL     GENERATED ALWAYS AS
                                     (total_ingresos - total_gastos_fijos - total_gastos_variables) STORED,
    observaciones           TEXT     NOT NULL DEFAULT '',
    fecha_generacion        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(mes, anio)
);

-- =============================================
-- ÍNDICES
-- =============================================
CREATE INDEX IF NOT EXISTS idx_productos_codigo    ON productos(codigo);
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(id_categoria);
CREATE INDEX IF NOT EXISTS idx_entradas_fecha      ON entradas_productos(fecha_entrada);
CREATE INDEX IF NOT EXISTS idx_entradas_producto   ON entradas_productos(id_producto);
CREATE INDEX IF NOT EXISTS idx_salidas_fecha       ON salidas_productos(fecha_salida);
CREATE INDEX IF NOT EXISTS idx_salidas_producto    ON salidas_productos(id_producto);
CREATE INDEX IF NOT EXISTS idx_salidas_lugar       ON salidas_productos(lugar_venta);
CREATE INDEX IF NOT EXISTS idx_salidas_venta       ON salidas_productos(id_venta);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha        ON ventas(fecha_venta);
CREATE INDEX IF NOT EXISTS idx_ventas_lugar        ON ventas(lugar_venta);
CREATE INDEX IF NOT EXISTS idx_control_fecha       ON control_diario(fecha);
CREATE INDEX IF NOT EXISTS idx_control_verbena     ON control_diario(es_verbena);
CREATE INDEX IF NOT EXISTS idx_resumen_mes_anio    ON resumen_mensual(mes, anio);

-- =============================================
-- TRIGGERS: fecha_actualizacion automática
-- Cada trigger usa WHEN para evitar recursión infinita.
-- =============================================
CREATE TRIGGER IF NOT EXISTS trg_usuarios_fecha
AFTER UPDATE ON usuarios
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE usuarios SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_usuario = NEW.id_usuario;
END;

CREATE TRIGGER IF NOT EXISTS trg_categorias_fecha
AFTER UPDATE ON categorias
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE categorias SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_categoria = NEW.id_categoria;
END;

CREATE TRIGGER IF NOT EXISTS trg_productos_fecha
AFTER UPDATE ON productos
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE productos SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_producto = NEW.id_producto;
END;

CREATE TRIGGER IF NOT EXISTS trg_entradas_fecha
AFTER UPDATE ON entradas_productos
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE entradas_productos SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_entrada = NEW.id_entrada;
END;

CREATE TRIGGER IF NOT EXISTS trg_salidas_fecha
AFTER UPDATE ON salidas_productos
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE salidas_productos SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_salida = NEW.id_salida;
END;

CREATE TRIGGER IF NOT EXISTS trg_ventas_fecha
AFTER UPDATE ON ventas
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE ventas SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_venta = NEW.id_venta;
END;

CREATE TRIGGER IF NOT EXISTS trg_control_fecha
AFTER UPDATE ON control_diario
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE control_diario SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_control = NEW.id_control;
END;

CREATE TRIGGER IF NOT EXISTS trg_resumen_fecha
AFTER UPDATE ON resumen_mensual
FOR EACH ROW
WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
BEGIN
    UPDATE resumen_mensual SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_resumen = NEW.id_resumen;
END;
