USE GimnasioDB;
GO


/* ANÁLISIS FINANCIERO: COMPARATIVA MENSUAL (MoM) */

WITH IngresosMensuales AS (
    SELECT 
        FORMAT(FechaPago, 'yyyy-MM') AS AnioMes,
        SUM(Monto) AS IngresoTotalMensual
    FROM 
        Finanzas.Pagos
    GROUP BY 
        FORMAT(FechaPago, 'yyyy-MM')
),
IngresosConMesAnterior AS (
    SELECT
        AnioMes,
        IngresoTotalMensual,
        LAG(IngresoTotalMensual, 1, 0) OVER (ORDER BY AnioMes ASC) AS IngresoMesAnterior
    FROM
        IngresosMensuales
)
SELECT 
    AnioMes,
    IngresoTotalMensual,
    (IngresoTotalMensual - IngresoMesAnterior) AS Diferencia,
    CAST(((IngresoTotalMensual - IngresoMesAnterior) * 100.0 / NULLIF(IngresoMesAnterior, 0)) AS DECIMAL(10, 2)) AS Crecimiento_Pct
FROM 
    IngresosConMesAnterior
ORDER BY 
    AnioMes DESC;
GO

/* ÍNDICE DE OPTIMIZACIÓN:
   -----------------------
   IX_Pagos_FechaPago
   
   La consulta agrupa y ordena masivamente por 'FechaPago'. Este índice mantiene las fechas 
   pre-ordenadas. Además, al incluir 'Monto',lo que significa que sql server puede resolver
   toda la consulta leyendo solo el índice sin tener que ir a la tabla de datos principal.
*/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Pagos_FechaPago')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pagos_FechaPago 
    ON Finanzas.Pagos(FechaPago) 
    INCLUDE (Monto);
    PRINT '>> Índice IX_Pagos_FechaPago creado exitosamente.';
END
GO



/* ANÁLISIS OPERATIVO: INSCRIPCIONES MENSUALES */


WITH ConteoAnualMes AS (
    SELECT 
        FORMAT(FechaInscripcion, 'yyyy-MM') AS AnioMes,
        COUNT(InscripcionID) AS TotalInscripciones
    FROM 
        Gestion.Inscripciones
    GROUP BY 
        FORMAT(FechaInscripcion, 'yyyy-MM')
),
InscripcionesConMesAnterior AS (
    SELECT
        AnioMes,
        TotalInscripciones,
        LAG(TotalInscripciones, 1, 0) OVER (ORDER BY AnioMes ASC) AS Anterior
    FROM
        ConteoAnualMes
)
SELECT 
    AnioMes, 
    TotalInscripciones, 
    (TotalInscripciones - Anterior) AS Diferencia,
    CAST(((TotalInscripciones - Anterior) * 100.0 / NULLIF(Anterior, 0)) AS DECIMAL(10, 2)) AS Crecimiento_Pct
FROM 
    InscripcionesConMesAnterior
ORDER BY 
    AnioMes DESC;
GO

/* ÍNDICE DE OPTIMIZACIÓN:
   -----------------------
   IX_Inscripciones_Fecha
   
   La tabla 'Inscripciones' es la más grande del sistema. Hacer un escaneo completo 
   para agrupar por fecha es muy costoso. Este índice permite a SQL Server acceder 
   directamente a las fechas ordenadas, acelerando drásticamente el GROUP BY y la función LAG().
*/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Inscripciones_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Inscripciones_Fecha 
    ON Gestion.Inscripciones(FechaInscripcion);
    PRINT '>> Índice IX_Inscripciones_Fecha creado exitosamente.';
END
GO



/* GESTIÓN: RANKING DE CLASES POPULARES */



WITH ConteoMensualPorClase AS (
    SELECT 
        FORMAT(i.FechaInscripcion, 'yyyy-MM') AS AnioMes,
        cc.NombreClase,
        COUNT(i.InscripcionID) AS TotalInscripciones
    FROM 
        Gestion.Inscripciones i
    JOIN 
        Gestion.Horarios h ON i.HorarioID = h.HorarioID
    JOIN 
        Gestion.Clases_Catalogo cc ON h.CatalogoID = cc.CatalogoID
    GROUP BY 
        FORMAT(i.FechaInscripcion, 'yyyy-MM'), cc.NombreClase
)
SELECT 
    AnioMes,
    DENSE_RANK() OVER (PARTITION BY AnioMes ORDER BY TotalInscripciones DESC) AS Ranking,
    NombreClase,
    TotalInscripciones
FROM 
    ConteoMensualPorClase
ORDER BY 
    AnioMes DESC, Ranking ASC;
GO

/* ÍNDICE DE OPTIMIZACIÓN:
   -----------------------
   IX_Horarios_CatalogoID
   
   Esta consulta une tres tablas (Inscripciones -> Horarios -> Catálogo). Este índice facilita la búsqueda del 'CatalogoID' 
   necesario para el JOIN final, evitando lecturas innecesarias de otras columnas de la tabla Horarios.
*/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Horarios_CatalogoID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Horarios_CatalogoID 
    ON Gestion.Horarios(CatalogoID) 
    INCLUDE (EntrenadorID, EspacioID);
    PRINT '>> Índice IX_Horarios_CatalogoID creado exitosamente.';
END
