-- Crear la base de datos
CREATE DATABASE IF NOT EXISTS sistema_ventas;
USE sistema_ventas;

-- 1. Tabla Categoria (No tiene dependencias)
CREATE TABLE Categoria (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre_categoria VARCHAR(100) NOT NULL
);

-- 2. Tabla Empleado (No tiene dependencias externas en el diagrama)
CREATE TABLE Empleado (
    id_empleado INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    usuario VARCHAR(50) NOT NULL,
    password VARCHAR(12) NOT NULL,
    rol VARCHAR(50) NOT NULL
);

-- 3. Tabla Cliente (No tiene dependencias)
CREATE TABLE Cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(50) NOT NULL,
    ci_nit VARCHAR(9),
    telefono VARCHAR(15),
    correo VARCHAR(50)
);

-- 4. Tabla Proveedor (No tiene dependencias)
CREATE TABLE Proveedor (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    nombre_empresa VARCHAR(100) NOT NULL,
    contacto_nombre VARCHAR(50),
    telefono VARCHAR(15),
    direccion TEXT
);

-- 5. Tabla Producto (Depende de Categoria)
CREATE TABLE Producto (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    marca VARCHAR(100),
    precio_venta DECIMAL(10, 2),
    stock INT,
    stock_minimo INT,
    foto VARCHAR(255), -- "varchar para ruta"
    id_categoria INT,
    FOREIGN KEY (id_categoria) REFERENCES Categoria(id_categoria)
);

-- 6. Tabla Venta (Depende de Cliente y Empleado)
CREATE TABLE Venta (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10, 2),
    id_cliente INT,
    id_empleado INT,
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente),
    FOREIGN KEY (id_empleado) REFERENCES Empleado(id_empleado)
);

-- 7. Tabla Compra (Depende de Proveedor y Empleado)
CREATE TABLE Compra (
    id_compra INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_compra DECIMAL(10, 2),
    id_proveedor INT,
    id_empleado INT,
    FOREIGN KEY (id_proveedor) REFERENCES Proveedor(id_proveedor),
    FOREIGN KEY (id_empleado) REFERENCES Empleado(id_empleado)
);

-- 8. Tabla Detalle de venta (Depende de Venta y Producto)
CREATE TABLE Detalle_venta (
    id_detalle_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_venta INT,
    id_producto INT,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (id_venta) REFERENCES Venta(id_venta) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);

-- 9. Tabla Detalle de compra (Depende de Compra y Producto)
CREATE TABLE Detalle_compra (
    id_detalle_compra INT AUTO_INCREMENT PRIMARY KEY,
    id_compra INT,
    id_producto INT,
    cantidad INT NOT NULL,
    costo_unitario DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (id_compra) REFERENCES Compra(id_compra) ON DELETE CASCADE,
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);
USE sistema_ventas;
-- 1. Insertar Categorías (Basado en la lista real)
INSERT INTO Categoria (nombre_categoria) VALUES
('Transmisión'),
('Accesorios y Chasis'),
('Llantas y Gomas'),
('Motor'),
('Sistema Eléctrico'),
('Frenos'),
('Filtros y Lubricantes');

-- 2. Insertar Productos (Nombres limpios, sin faltas de ortografía, con stock real del WhatsApp)
-- Nota: Los precios (precio_costo y precio_venta) son estimaciones para prueba. 
-- El stock_minimo está seteado en 5 para que C# dispare alertas.
INSERT INTO Producto (nombre, descripcion, marca, precio_venta, stock, stock_minimo, id_categoria) VALUES
('Piñón 520', 'Piñón de transmisión paso 520', 'Genérico', 45.00, 10, 5, 1),
('Goma Cachuda 100/90-18', 'Neumático trasero con tacos', 'Genérico', 280.00, 2, 4, 3),
('Rodamiento 6204', 'Rodamiento universal de rueda/motor', 'Genérico', 25.00, 10, 5, 4),
('Filtro de Aire Brozz', 'Elemento filtrante de aire', 'Brozz', 35.00, 4, 5, 7), -- Este disparará alerta (4 < 5)
('Batería 12V 7A', 'Batería de gel libre mantenimiento', 'Kanda', 180.00, 1, 3, 5), -- Este disparará alerta (1 < 3)
('Transmisión Boxer', 'Kit de arrastre completo', 'Boxer', 150.00, 10, 4, 1),
('Válvulas 150cc', 'Juego de válvulas de admisión y escape', 'Genérico', 55.00, 15, 5, 4),
('Motor de Arranque 150cc', 'Motor de partida', 'Kanda', 220.00, 2, 2, 5),
('CDI Kanda', 'Módulo de encendido electrónico', 'Kanda', 65.00, 5, 3, 5),
('Cámara 300/18', 'Cámara de aire para llanta', 'Genérico', 40.00, 50, 10, 3),
('Carburador 150cc', 'Carburador completo PZ27', 'Genérico', 140.00, 5, 2, 4),
('Bomba de Freno Delantero Brozz', 'Cilindro maestro de freno', 'Brozz', 110.00, 2, 2, 6);