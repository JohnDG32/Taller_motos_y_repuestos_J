-- =============================================================
--  BASE DE DATOS: Taller y Ventas de Repuestos Josué
--  Motor: SQLite 3.25+
--  IMPORTANTE: Ejecutar siempre al abrir conexión en C#:
--              PRAGMA foreign_keys = ON;
-- =============================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;  -- mejor rendimiento en lecturas concurrentes

-- =============================================================
-- MÓDULO: SEGURIDAD
-- =============================================================

CREATE TABLE IF NOT EXISTS rol (
    id_rol          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_rol      TEXT    NOT NULL,
    descripcion     TEXT
);

CREATE TABLE IF NOT EXISTS permisos (
    id_permiso      INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_permiso    TEXT    NOT NULL
);

-- Tabla pivot rol <-> permisos (muchos a muchos)
CREATE TABLE IF NOT EXISTS rol_permisos (
    id_rol          INTEGER NOT NULL,
    id_permiso      INTEGER NOT NULL,
    PRIMARY KEY (id_rol, id_permiso),
    FOREIGN KEY (id_rol)       REFERENCES rol(id_rol)           ON DELETE CASCADE,
    FOREIGN KEY (id_permiso)   REFERENCES permisos(id_permiso)  ON DELETE CASCADE
);

-- =============================================================
-- MÓDULO: EMPLEADOS Y USUARIOS
-- Un empleado puede existir sin usuario.
-- El admin crea usuarios aparte y los vincula a un empleado.
-- =============================================================

CREATE TABLE IF NOT EXISTS empleado (
    id_empleado         INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_empleado     TEXT    NOT NULL,
    apellido_paterno    TEXT    NOT NULL,
    apellido_materno    TEXT,
    ci                  TEXT    NOT NULL UNIQUE,
    correo              TEXT    UNIQUE,
    direccion           TEXT,
    telefono            TEXT,
    fecha_ingreso       TEXT    NOT NULL,   -- formato ISO: 'YYYY-MM-DD'
    fecha_salida        TEXT                -- NULL = empleado activo
);

CREATE TABLE IF NOT EXISTS usuario (
    id_usuario          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_usuario      TEXT    NOT NULL UNIQUE,
    contrasena          TEXT    NOT NULL,   -- guardar siempre como hash (bcrypt/SHA-256)
    id_empleado         INTEGER NOT NULL,
    id_rol              INTEGER NOT NULL,
    FOREIGN KEY (id_empleado)  REFERENCES empleado(id_empleado) ON DELETE RESTRICT,
    FOREIGN KEY (id_rol)       REFERENCES rol(id_rol)           ON DELETE RESTRICT
);

-- =============================================================
-- MÓDULO: CATÁLOGO
-- Categoría con jerarquía (RF2): id_categoria_padre NULL = raíz
-- =============================================================

CREATE TABLE IF NOT EXISTS categoria (
    id_categoria        INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_categoria    TEXT    NOT NULL,
    id_categoria_padre  INTEGER,            -- NULL = categoría raíz
    FOREIGN KEY (id_categoria_padre) REFERENCES categoria(id_categoria) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS producto (
    id_producto         INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_producto     TEXT            NOT NULL,
    descripcion         TEXT,
    marca               TEXT,
    precio              REAL            NOT NULL CHECK (precio >= 0),
    stock_actual        INTEGER         NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo        INTEGER         NOT NULL DEFAULT 5,
    id_categoria        INTEGER         NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria) ON DELETE RESTRICT
);

-- =============================================================
-- MÓDULO: CLIENTES
-- =============================================================

CREATE TABLE IF NOT EXISTS cliente (
    id_cliente          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre              TEXT    NOT NULL,
    apellido_paterno    TEXT    NOT NULL,
    apellido_materno    TEXT,
    ci                  TEXT    NOT NULL UNIQUE,
    correo              TEXT    UNIQUE,
    telefono            TEXT
);

-- =============================================================
-- MÓDULO: VENTAS
-- =============================================================

CREATE TABLE IF NOT EXISTS venta (
    id_venta            INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha_venta         TEXT    NOT NULL DEFAULT (datetime('now')),  -- ISO: 'YYYY-MM-DD HH:MM:SS'
    venta_total         REAL    NOT NULL DEFAULT 0.00,
    id_cliente          INTEGER NOT NULL,
    id_empleado         INTEGER NOT NULL,
    FOREIGN KEY (id_cliente)   REFERENCES cliente(id_cliente)   ON DELETE RESTRICT,
    FOREIGN KEY (id_empleado)  REFERENCES empleado(id_empleado) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS detalle_venta (
    id_detalle_venta    INTEGER PRIMARY KEY AUTOINCREMENT,
    cantidad            INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario     REAL    NOT NULL CHECK (precio_unitario > 0),
    sub_total           REAL    NOT NULL,   -- calculado: cantidad * precio_unitario
    id_venta            INTEGER NOT NULL,
    id_producto         INTEGER NOT NULL,
    FOREIGN KEY (id_venta)     REFERENCES venta(id_venta)       ON DELETE CASCADE,
    FOREIGN KEY (id_producto)  REFERENCES producto(id_producto) ON DELETE RESTRICT
);

-- =============================================================
-- MÓDULO: PROVEEDORES Y COMPRAS
-- =============================================================

CREATE TABLE IF NOT EXISTS proveedor (
    id_proveedor        INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_proveedor    TEXT    NOT NULL,
    nombre_empresa      TEXT,
    ci                  TEXT    UNIQUE,
    correo              TEXT    UNIQUE,
    direccion           TEXT,
    telefono            TEXT
);

CREATE TABLE IF NOT EXISTS compra (
    id_compra           INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha_compra        TEXT    NOT NULL DEFAULT (datetime('now')),
    total_compra        REAL    NOT NULL DEFAULT 0.00,
    id_proveedor        INTEGER NOT NULL,
    id_empleado         INTEGER NOT NULL,
    FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor) ON DELETE RESTRICT,
    FOREIGN KEY (id_empleado)  REFERENCES empleado(id_empleado)   ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS detalle_compra (
    id_detalle_compra   INTEGER PRIMARY KEY AUTOINCREMENT,
    cantidad            INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario     REAL    NOT NULL CHECK (precio_unitario > 0),
    sub_total           REAL    NOT NULL,
    id_compra           INTEGER NOT NULL,
    id_producto         INTEGER NOT NULL,
    FOREIGN KEY (id_compra)    REFERENCES compra(id_compra)      ON DELETE CASCADE,
    FOREIGN KEY (id_producto)  REFERENCES producto(id_producto)  ON DELETE RESTRICT
);

-- =============================================================
-- TRIGGERS: Actualización automática de stock y totales
-- SQLite no usa DELIMITER, cada trigger es una sentencia completa
-- =============================================================

-- Descuenta stock al registrar línea de venta
CREATE TRIGGER IF NOT EXISTS trg_descuenta_stock
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE producto
    SET stock_actual = stock_actual - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END;

-- Suma stock al registrar línea de compra
CREATE TRIGGER IF NOT EXISTS trg_suma_stock
AFTER INSERT ON detalle_compra
FOR EACH ROW
BEGIN
    UPDATE producto
    SET stock_actual = stock_actual + NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END;

-- Recalcula total de la venta al insertar detalle
CREATE TRIGGER IF NOT EXISTS trg_total_venta
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE venta
    SET venta_total = (
        SELECT COALESCE(SUM(sub_total), 0)
        FROM detalle_venta
        WHERE id_venta = NEW.id_venta
    )
    WHERE id_venta = NEW.id_venta;
END;

-- Recalcula total de la compra al insertar detalle
CREATE TRIGGER IF NOT EXISTS trg_total_compra
AFTER INSERT ON detalle_compra
FOR EACH ROW
BEGIN
    UPDATE compra
    SET total_compra = (
        SELECT COALESCE(SUM(sub_total), 0)
        FROM detalle_compra
        WHERE id_compra = NEW.id_compra
    )
    WHERE id_compra = NEW.id_compra;
END;

-- =============================================================
-- ÍNDICES: Rendimiento en consultas frecuentes (RNF3)
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_producto_categoria  ON producto(id_categoria);
CREATE INDEX IF NOT EXISTS idx_venta_cliente        ON venta(id_cliente);
CREATE INDEX IF NOT EXISTS idx_venta_empleado       ON venta(id_empleado);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_venta  ON detalle_venta(id_venta);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_prod   ON detalle_venta(id_producto);
CREATE INDEX IF NOT EXISTS idx_detalle_compra_comp  ON detalle_compra(id_compra);
CREATE INDEX IF NOT EXISTS idx_detalle_compra_prod  ON detalle_compra(id_producto);
CREATE INDEX IF NOT EXISTS idx_compra_proveedor     ON compra(id_proveedor);

-- =============================================================
-- VISTA: Productos bajo stock mínimo (RF3)
-- Consumir desde C# al iniciar sesión para mostrar alertas
-- =============================================================

CREATE VIEW IF NOT EXISTS vista_alerta_stock AS
SELECT
    p.id_producto,
    p.nombre_producto,
    p.marca,
    c.nombre_categoria,
    p.stock_actual,
    p.stock_minimo,
    (p.stock_minimo - p.stock_actual) AS unidades_faltantes
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.stock_actual <= p.stock_minimo;

-- ----------------------------------------------------------------------------------------------
-- Trigger: Devolver stock si se borra un item de la venta (Corrección de errores)
CREATE TRIGGER IF NOT EXISTS trg_anular_item_venta
AFTER DELETE ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE producto
    SET stock_actual = stock_actual + OLD.cantidad
    WHERE id_producto = OLD.id_producto;
END;

-- Trigger: Recalcular total si se borra un item de la venta
CREATE TRIGGER IF NOT EXISTS trg_total_venta_delete
AFTER DELETE ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE venta
    SET venta_total = (
        SELECT COALESCE(SUM(sub_total), 0)
        FROM detalle_venta
        WHERE id_venta = OLD.id_venta
    )
    WHERE id_venta = OLD.id_venta;
END;

-- (Haz lo mismo para Compras: trg_anular_item_compra y trg_total_compra_delete)

-- Trigger: Restar stock si se elimina un item de la COMPRA
CREATE TRIGGER IF NOT EXISTS trg_anular_item_compra
AFTER DELETE ON detalle_compra
FOR EACH ROW
BEGIN
    UPDATE producto
    SET stock_actual = stock_actual - OLD.cantidad
    WHERE id_producto = OLD.id_producto;
END;

-- Trigger: Recalcular total de la COMPRA al borrar un item
CREATE TRIGGER IF NOT EXISTS trg_total_compra_delete
AFTER DELETE ON detalle_compra
FOR EACH ROW
BEGIN
    UPDATE compra
    SET total_compra = (
        SELECT COALESCE(SUM(sub_total), 0)
        FROM detalle_compra
        WHERE id_compra = OLD.id_compra
    )
    WHERE id_compra = OLD.id_compra;
END;

