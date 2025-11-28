# Sistema de Gestión de Reservas de Gimnasio

**Universidad Centroamericana José Simeón Cañas (UCA)**
**Departamento de Electrónica e Informática**
**Materia:** Administración de Base de Datos

## Descripción del Proyecto

Este proyecto consiste en el diseño, implementación y administración de una base de datos relacional para la gestión integral de un gimnasio. El sistema permite administrar socios, entrenadores, horarios, espacios físicos, inscripciones a clases y transacciones financieras.

El objetivo es ofrecer una gestión dinámica de reservas y socios, priorizando la seguridad de los datos y la escalabilidad del negocio.

## Integrantes del Equipo

* **Sandoval Chevez, Luis Gerardo** (00014524)
* **Amaya Sánchez, Samuel Francisco** (00026724)
* **Morales Vargas, Julio Javier** (00076124)
* **Lopez Menjivar, Andres Rodolfo** (00084724)

---

## Arquitectura de la Base de Datos

La base de datos está organizada en **Esquemas** para separar lógicamente los objetos y facilitar la gestión de seguridad:

| Esquema | Descripción | Tablas Principales |
| :--- | :--- | :--- |
| **Personas** | Gestión de identidad de clientes (Datos sensibles). | `Socios` |
| **Finanzas** | Gestión económica y facturación (Crítica). | `Pagos`, `Facturas` |
| **Empleado** | Gestión de Recursos Humanos. | `Entrenadores` |
| **Gestion** | Operativa diaria del negocio. | `Clases_Catalogo`, `Espacios`, `Horarios`, `Inscripciones` |

---

## Seguridad y Auditoría

El sistema implementa una política de seguridad basada en roles y auditoría:

### Roles y Permisos
1.  **Rol_Gerente**
2.  **Rol_Recepcion**
3.  **Rol_Entrenador**
   
### Auditoría (SQL Server Audit)
Se monitorean eventos críticos para mitigar riesgos:
* **Control Financiero**: Cambios en la tabla `Pagos` por parte de recepción.
* **Integridad de Datos**: Eliminaciones en la tabla `Inscripciones`.
* **Seguridad de Acceso**: Intentos de inicio de sesión fallidos.

---

## Funciones y Optimización

Se incluyen scripts para análisis de negocio y mejoras de rendimiento:

### Análisis de Negocio
* **Finanzas**: Comparativa mensual de ingresos (Month-over-Month).
* **Operaciones**: Tendencia de inscripciones y crecimiento porcentual.
* **Ranking**: Clases más populares (ej. Yoga, CrossFit) mediante `DENSE_RANK`.

### Índices de Rendimiento
Se crearon índices Non-Clustered para acelerar consultas frecuentes:
* `IX_Pagos_FechaPago`
* `IX_Inscripciones_Fecha`
* `IX_Horarios_CatalogoID`

---

## Estrategia de Respaldo

Diseño híbrido para minimizar la pérdida de datos (RPO < 1 hora):

* **Completo (Full)**: Semanal (Domingos 00:00).
* **Diferencial**: Diario (Lunes a Sábado 00:00).
* **Log de Transacciones**: Cada hora (07:00 AM - 10:00 PM).

---

## Integración y Visualización

* **Migración (ETL)**: Uso de **SSIS (SQL Server Integration Services)** para la carga masiva y transformación de datos desde Excel/CSV.
* **Visualización**: Dashboard en **Power BI** (`visuals.pbix`) para el monitoreo de indicadores clave.
