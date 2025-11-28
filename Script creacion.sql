/* =========================================================
   SCRIPT MAESTRO: CREACIÓN DE ESTRUCTURA GIMNASIODB
=========================================================
*/
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'GimnasioDB')
BEGIN
    ALTER DATABASE GimnasioDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GimnasioDB;
END
GO

CREATE DATABASE GimnasioDB;
PRINT 'Base de datos GimnasioDB creada.';
GO

USE GimnasioDB;
GO

/* =========================================================
   PASO 1: CREACIÓN DE ESQUEMAS
=========================================================
*/
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Personas') EXEC('CREATE SCHEMA Personas');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Finanzas') EXEC('CREATE SCHEMA Finanzas');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Gestion') EXEC('CREATE SCHEMA Gestion');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Empleado') EXEC('CREATE SCHEMA Empleado');
GO

/* =========================================================
   PASO 2: TABLAS Y OBJETOS
=========================================================
*/

-- 1. ESQUEMA EMPLEADO (Entrenadores)
CREATE TABLE Empleado.Entrenadores (
    EntrenadorID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Apellido NVARCHAR(100) NOT NULL,
    Cargo NVARCHAR(100) DEFAULT 'Entrenador',
    Especialidad NVARCHAR(100),
    Email NVARCHAR(100) UNIQUE NOT NULL,
    FechaContratacion DATE DEFAULT GETDATE(),
    Genero CHAR(1) NOT NULL,
    CONSTRAINT CHK_Entrenadores_Genero CHECK (Genero IN ('M', 'F', 'O'))
);

-- 2. ESQUEMA PERSONAS (Socios)
CREATE TABLE Personas.Socios (
    SocioID INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Apellido NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE NOT NULL,
    FechaInscripcion DATE DEFAULT GETDATE(),
    TipoMembresia NVARCHAR(50) CHECK (TipoMembresia IN ('Mensual', 'Trimestral', 'Anual')) NOT NULL,
    Genero CHAR(1) NOT NULL,
    CONSTRAINT CHK_Socios_Genero CHECK (Genero IN ('M', 'F', 'O'))
);

-- 3. ESQUEMA FINANZAS (Pagos y Facturas)

-- Secuenciador para Pagos
IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'SecuenciaPagos' AND schema_id = SCHEMA_ID('Finanzas'))
BEGIN
    CREATE SEQUENCE Finanzas.SecuenciaPagos
    START WITH 1
    INCREMENT BY 1;
END
GO

CREATE TABLE Finanzas.Pagos (
    PagoID INT PRIMARY KEY DEFAULT (NEXT VALUE FOR Finanzas.SecuenciaPagos),
    SocioID INT FOREIGN KEY REFERENCES Personas.Socios(SocioID) ON DELETE CASCADE NOT NULL,
    Monto DECIMAL(10, 2) NOT NULL,
    FechaPago DATETIME DEFAULT GETDATE(),
    Concepto NVARCHAR(200)
);

CREATE TABLE Finanzas.Facturas (
    FacturaID INT PRIMARY KEY IDENTITY(1,1),
    PagoID INT NOT NULL UNIQUE, -- Relación 1 a 1 con Pagos
    FechaEmision DATETIME DEFAULT GETDATE(),
    RUC_NIT NVARCHAR(20),
    DireccionFacturacion NVARCHAR(200),
    EstadoFactura NVARCHAR(50) DEFAULT 'Emitida' CHECK (EstadoFactura IN ('Emitida', 'Anulada')),
    CONSTRAINT FK_Facturas_Pagos FOREIGN KEY (PagoID) REFERENCES Finanzas.Pagos(PagoID)
);

-- 4. ESQUEMA GESTION (Clases, Espacios, Horarios, Inscripciones)
CREATE TABLE Gestion.Espacios (
    EspacioID INT PRIMARY KEY IDENTITY(1,1),
    NombreEspacio NVARCHAR(100) NOT NULL UNIQUE,
    Descripcion NVARCHAR(250)
);

CREATE TABLE Gestion.Clases_Catalogo (
    CatalogoID INT PRIMARY KEY IDENTITY(1,1),
    NombreClase NVARCHAR(100) NOT NULL UNIQUE,
    Descripcion NVARCHAR(500)
);

CREATE TABLE Gestion.Espacio_ClasesPermitidas (
    EspacioID INT NOT NULL,
    CatalogoID INT NOT NULL,
    CONSTRAINT FK_EspacioClase_Espacio FOREIGN KEY (EspacioID) REFERENCES Gestion.Espacios(EspacioID) ON DELETE CASCADE,
    CONSTRAINT FK_EspacioClase_Catalogo FOREIGN KEY (CatalogoID) REFERENCES Gestion.Clases_Catalogo(CatalogoID) ON DELETE CASCADE,
    CONSTRAINT PK_Espacio_ClasesPermitidas PRIMARY KEY (EspacioID, CatalogoID)
);

CREATE TABLE Gestion.Horarios (
    HorarioID INT PRIMARY KEY IDENTITY(1,1),
    EntrenadorID INT FOREIGN KEY REFERENCES Empleado.Entrenadores(EntrenadorID),
    EspacioID INT NOT NULL,
    CatalogoID INT NOT NULL,
    DiaDeLaSemana INT NOT NULL CHECK (DiaDeLaSemana BETWEEN 1 AND 7), -- 1=Lunes, 7=Domingo
    HoraInicio TIME NOT NULL,
    HoraFin TIME NOT NULL,
    CapacidadMaxima INT NOT NULL,
    CONSTRAINT FK_Horario_EspacioCatalogo FOREIGN KEY (EspacioID, CatalogoID) 
        REFERENCES Gestion.Espacio_ClasesPermitidas (EspacioID, CatalogoID)
);

CREATE TABLE Gestion.Inscripciones (
    InscripcionID INT PRIMARY KEY IDENTITY(1,1),
    SocioID INT FOREIGN KEY REFERENCES Personas.Socios(SocioID) ON DELETE CASCADE NOT NULL,
    HorarioID INT FOREIGN KEY REFERENCES Gestion.Horarios(HorarioID) ON DELETE CASCADE NOT NULL,
    FechaInscripcion DATE DEFAULT GETDATE()
);

/* =========================================================
   PASO 3: VISTAS Y TRIGGERS
=========================================================
*/

-- 1. VISTAS
IF OBJECT_ID('V_EstadoSocios', 'V') IS NOT NULL DROP VIEW V_EstadoSocios;
GO
CREATE VIEW V_EstadoSocios AS
SELECT 
    s.SocioID, s.Nombre, s.Apellido, s.Email, s.TipoMembresia,
    ISNULL(p.UltimoPago, '1900-01-01') AS UltimoPago,
    CASE 
        WHEN p.UltimoPago IS NULL THEN 'Pendiente (Sin Pagos)'
        WHEN s.TipoMembresia = 'Mensual' AND DATEDIFF(day, p.UltimoPago, GETDATE()) > 30 THEN 'Pendiente'
        WHEN s.TipoMembresia = 'Trimestral' AND DATEDIFF(day, p.UltimoPago, GETDATE()) > 90 THEN 'Pendiente'
        WHEN s.TipoMembresia = 'Anual' AND DATEDIFF(day, p.UltimoPago, GETDATE()) > 365 THEN 'Pendiente'
        ELSE 'Al Dia'
    END AS EstadoPago
FROM Personas.Socios s
LEFT JOIN (
    SELECT SocioID, MAX(FechaPago) AS UltimoPago FROM Finanzas.Pagos GROUP BY SocioID
) p ON s.SocioID = p.SocioID;
GO

IF OBJECT_ID('V_Socios_Basico', 'V') IS NOT NULL DROP VIEW V_Socios_Basico;
GO
CREATE VIEW V_Socios_Basico AS
SELECT Nombre, Apellido FROM Personas.Socios;
GO

-- 2. TRIGGERS

-- Trigger: Conflictos de Horario
IF OBJECT_ID('Gestion.TR_Horarios_Conflictos', 'TR') IS NOT NULL DROP TRIGGER Gestion.TR_Horarios_Conflictos;
GO
CREATE TRIGGER Gestion.TR_Horarios_Conflictos ON Gestion.Horarios AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM Gestion.Horarios h JOIN inserted i ON h.EspacioID = i.EspacioID AND h.DiaDeLaSemana = i.DiaDeLaSemana AND h.HorarioID <> i.HorarioID
        WHERE (i.HoraInicio < h.HoraFin) AND (i.HoraFin > h.HoraInicio)
    ) BEGIN
        RAISERROR ('Error: El ESPACIO ya está reservado en ese día y hora.', 16, 1); ROLLBACK TRANSACTION; RETURN;
    END
    IF EXISTS (
        SELECT 1 FROM Gestion.Horarios h JOIN inserted i ON h.EntrenadorID = i.EntrenadorID AND h.DiaDeLaSemana = i.DiaDeLaSemana AND h.HorarioID <> i.HorarioID
        WHERE (i.HoraInicio < h.HoraFin) AND (i.HoraFin > h.HoraInicio)
    ) BEGIN
        RAISERROR ('Error: El ENTRENADOR ya está asignado a otra clase.', 16, 1); ROLLBACK TRANSACTION; RETURN;
    END
END;
GO

-- Trigger: Validación de Inscripciones
IF OBJECT_ID('Gestion.TR_Inscripciones_Validaciones', 'TR') IS NOT NULL DROP TRIGGER Gestion.TR_Inscripciones_Validaciones;
GO
CREATE TRIGGER Gestion.TR_Inscripciones_Validaciones ON Gestion.Inscripciones AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SocioID INT, @HorarioID INT, @FechaInsc DATE, @DiaSemanaHorario INT, @Capacidad INT, @Inicio TIME, @Fin TIME;
    DECLARE @DiaSemanaFecha INT;

    SELECT @SocioID = i.SocioID, @HorarioID = i.HorarioID, @FechaInsc = i.FechaInscripcion FROM inserted i;
    SELECT @DiaSemanaHorario = h.DiaDeLaSemana, @Capacidad = h.CapacidadMaxima, @Inicio = h.HoraInicio, @Fin = h.HoraFin 
    FROM Gestion.Horarios h WHERE h.HorarioID = @HorarioID;

    -- Cálculo del día de la semana (Lunes = 1)
    SET @DiaSemanaFecha = ((DATEPART(dw, @FechaInsc) + @@DATEFIRST - 2) % 7) + 1;

    IF (@DiaSemanaFecha <> @DiaSemanaHorario) BEGIN
        RAISERROR ('Error: La fecha no coincide con el día del horario (Lunes=1).', 16, 1); ROLLBACK TRANSACTION; RETURN;
    END
    
    IF ((SELECT COUNT(*) FROM Gestion.Inscripciones WHERE HorarioID = @HorarioID AND FechaInscripcion = @FechaInsc) > @Capacidad) BEGIN
        RAISERROR ('Error: Clase llena.', 16, 1); ROLLBACK TRANSACTION; RETURN;
    END
    
    IF EXISTS (
        SELECT 1 FROM Gestion.Inscripciones i JOIN Gestion.Horarios h ON i.HorarioID = h.HorarioID
        WHERE i.SocioID = @SocioID AND i.FechaInscripcion = @FechaInsc AND i.HorarioID <> @HorarioID AND (h.HoraInicio < @Fin) AND (h.HoraFin > @Inicio)
    ) BEGIN
        RAISERROR ('Error: El socio ya tiene otra clase a esa hora.', 16, 1); ROLLBACK TRANSACTION; RETURN;
    END
END;
GO

/* =========================================================
   PASO 4: SEGURIDAD (ROLES Y PERMISOS)
=========================================================
*/

-- 1. ROLES
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Rol_Gerente' AND type = 'R') CREATE ROLE Rol_Gerente;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Rol_Recepcion' AND type = 'R') CREATE ROLE Rol_Recepcion;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Rol_Entrenador' AND type = 'R') CREATE ROLE Rol_Entrenador;
GO

-- 2. PERMISOS

-- Gerente: Acceso total por Esquemas
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Personas TO Rol_Gerente;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Finanzas TO Rol_Gerente;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Gestion TO Rol_Gerente;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Empleado TO Rol_Gerente;
GRANT VIEW DEFINITION TO Rol_Gerente;

-- Recepción: Permisos Operativos
GRANT SELECT, INSERT, UPDATE ON Personas.Socios TO Rol_Recepcion;
GRANT SELECT, INSERT ON Finanzas.Pagos TO Rol_Recepcion;
GRANT SELECT, INSERT ON Finanzas.Facturas TO Rol_Recepcion;
GRANT SELECT, INSERT, DELETE ON Gestion.Inscripciones TO Rol_Recepcion;
GRANT SELECT ON V_EstadoSocios TO Rol_Recepcion;

-- Lectura de catálogos
GRANT SELECT ON Gestion.Horarios TO Rol_Recepcion;
GRANT SELECT ON Gestion.Clases_Catalogo TO Rol_Recepcion;
GRANT SELECT ON Gestion.Espacios TO Rol_Recepcion;
GRANT SELECT ON Empleado.Entrenadores TO Rol_Recepcion;

-- Entrenador: Mínimo Privilegio
GRANT SELECT ON Empleado.Entrenadores TO Rol_Entrenador;
GRANT SELECT ON Gestion.Horarios TO Rol_Entrenador;
GRANT SELECT ON Gestion.Inscripciones TO Rol_Entrenador;
GRANT SELECT ON Gestion.Clases_Catalogo TO Rol_Entrenador;
GRANT SELECT ON Gestion.Espacios TO Rol_Entrenador;
GRANT SELECT ON V_Socios_Basico TO Rol_Entrenador; -- Vista restringida
-- (No tiene acceso a Personas ni Finanzas)

-- 3. USUARIOS Y LOGINS
USE master;
GO
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Login_Gerente') CREATE LOGIN Login_Gerente WITH PASSWORD = 'Password123!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Login_Recepcion') CREATE LOGIN Login_Recepcion WITH PASSWORD = 'Password123!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Login_Entrenador') CREATE LOGIN Login_Entrenador WITH PASSWORD = 'Password123!', CHECK_POLICY = OFF;
GO

USE GimnasioDB;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'User_Gerente') CREATE USER User_Gerente FOR LOGIN Login_Gerente;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'User_Recepcion') CREATE USER User_Recepcion FOR LOGIN Login_Recepcion;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'User_Entrenador') CREATE USER User_Entrenador FOR LOGIN Login_Entrenador;

ALTER ROLE Rol_Gerente ADD MEMBER User_Gerente;
ALTER ROLE Rol_Recepcion ADD MEMBER User_Recepcion;
ALTER ROLE Rol_Entrenador ADD MEMBER User_Entrenador;
GO


PRINT 'Estructura Completa';
GO