# LabTrack — Manual de Usuario

> Versión 1.0 · Mayo 2026

---

## Tabla de contenidos

1. [¿Qué es LabTrack?](#1-qué-es-labtrack)
2. [Primeros pasos](#2-primeros-pasos)
3. [Dashboard](#3-dashboard)
4. [Inventario](#4-inventario)
5. [Productos](#5-productos)
6. [Movimientos](#6-movimientos)
7. [Conteo de inventario](#7-conteo-de-inventario)
8. [Reportes](#8-reportes)
9. [Configuración](#9-configuración)
10. [Escaneo de código de barras](#10-escaneo-de-código-de-barras)
11. [Sincronización y uso sin conexión](#11-sincronización-y-uso-sin-conexión)
12. [Dos tipos de laboratorio](#12-dos-tipos-de-laboratorio)

---

## 1. ¿Qué es LabTrack?

LabTrack es una aplicación móvil para el control de inventario de laboratorio. Permite:

- Registrar productos con o sin número de lote
- Controlar entradas, salidas, devoluciones y ajustes de stock
- Hacer conteos periódicos de inventario (semanal, mensual, etc.)
- Ver reportes de consumo, tendencia histórica y discrepancias
- Trabajar sin conexión a internet — los datos se sincronizan automáticamente cuando hay red
- Gestionar múltiples laboratorios desde la misma cuenta

---

## 2. Primeros pasos

### 2.1 Inicio de sesión

Al abrir la app por primera vez verás la pantalla de **Login**.

- Ingresa tu correo electrónico y contraseña.
- Si aún no tienes cuenta, usa el enlace **Sign up** para registrarte.
- Una vez autenticado, la app te llevará al selector de laboratorio.

### 2.2 Seleccionar o crear un laboratorio

En la pantalla **Lab Picker**:

- Si ya perteneces a un laboratorio, aparecerá en la lista — tócalo para entrar.
- Para crear uno nuevo, toca el botón **Create new lab**, ingresa el nombre y confirma.
- Si tienes invitación a un laboratorio existente, el administrador debe agregarte desde la configuración.

> Puedes cambiar de laboratorio en cualquier momento desde **Configuración → Cambiar laboratorio**.

---

## 3. Dashboard

El Dashboard es la pantalla de inicio. Muestra un resumen del estado actual del inventario.

### Indicadores (KPI)

| Indicador | Descripción |
|-----------|-------------|
| **Products** | Total de productos activos registrados |
| **Alerts** | Número de productos con stock crítico o agotado |
| **Reorder** | Productos que han bajado del punto de reorden |

### Secciones de alerta

- **Critical Stock** — productos por debajo del nivel mínimo configurado. Toca cualquier tarjeta para ir al detalle del producto.
- **Reorder Needed** — productos que bajaron del punto de reorden pero aún no están en nivel crítico.
- **Expiring Soon (≤ 30 días)** — lotes con fecha de vencimiento próxima. Muestra el lote específico y su fecha.
- **All clear** — aparece cuando no hay ninguna alerta activa.

### Acciones rápidas

- **Configuración** (ícono engranaje, esquina superior derecha) → abre la pantalla de Configuración.
- **Sign out** (ícono salida) → cierra sesión.

---

## 4. Inventario

La pestaña **Inventory** muestra todos los productos activos con su cantidad actual de stock.

### Buscar y filtrar

- **Barra de búsqueda** — filtra por nombre de producto o código de barras. El ícono de limpiar (×) aparece cuando hay texto ingresado.
- **Escanear código de barras** (ícono escáner, AppBar) — abre la cámara para buscar por código.
- **Chips de estado** — filtra la lista por estado de stock:
  - `All` — todos los productos
  - `OK` — stock dentro de los niveles normales
  - `Reorder` — por debajo del punto de reorden
  - `Critical` — por debajo del stock mínimo
  - `Out` — stock en cero

### Tarjeta de producto

Cada tarjeta muestra:
- Nombre del producto y unidad de medida
- Código de barras (si tiene)
- Indicador de si el producto usa lotes o cantidad directa
- **Badge de stock** con color indicativo:
  - Verde → OK
  - Amarillo → reorden
  - Rojo → crítico o agotado

Toca una tarjeta para ver el **detalle del producto** (lotes, cantidades por lote, fechas de vencimiento).

### Agregar producto

Toca el botón **+ Add product** (esquina inferior derecha) para ir al formulario de alta de producto.

---

## 5. Productos

La pantalla **Products** (accesible desde Inventario → Add product, o desde el catálogo general) muestra todos los productos registrados.

### Agregar un producto nuevo

Toca el ícono **+** en el AppBar. El formulario solicita:

| Campo | Obligatorio | Descripción |
|-------|-------------|-------------|
| Nombre | Sí | Nombre descriptivo del producto |
| Unidad | Sí | Unidad de medida (mL, g, L, unidades, etc.) |
| Código de barras | No | Escaneable con la cámara |
| Categoría | No | Selecciona de las categorías configuradas |
| Proveedor | No | Selecciona del catálogo de proveedores |
| Ubicación | No | Lugar de almacenamiento |
| Condición de almacenamiento | No | Temperatura, humedad, sensibilidad a la luz |
| Stock mínimo | No | Nivel crítico — activa alerta cuando se llega a este nivel |
| Punto de reorden | No | Nivel de reorden — activa alerta preventiva |
| **Tracks lots** | No | Actívalo si este producto se controla por número de lote y fecha de vencimiento |

> **¿Tracks lots?** — Si está activado, el stock se calcula sumando las cantidades de todos los lotes activos. Si está desactivado, el stock es un valor directo que se actualiza con movimientos.

### Editar un producto

Desde la lista de productos, toca el producto y luego el ícono de editar, o toca directamente la fila en la pantalla de Inventario.

---

## 6. Movimientos

La pestaña **Movements** registra todas las transacciones que afectan el stock. Cada movimiento queda guardado en el historial.

### Tipos de movimiento

| Tipo | Cuándo usarlo |
|------|---------------|
| **Entry** | Recepción de nueva mercancía o reabastecimiento |
| **Exit** | Consumo o dispensación de un producto |
| **Return** | Devolución de un producto al inventario (ej. sobrante de un experimento) |

### Registrar un movimiento

1. Toca el botón correspondiente en la pantalla de Movimientos:
   - **Entry** (botón primario verde)
   - **Exit** (botón primario, fila superior)
   - **Return** (botón secundario, fila inferior)
2. Selecciona el producto (búsqueda por nombre o escáner).
3. Si el producto usa lotes, selecciona el lote o crea uno nuevo (para entradas).
4. Ingresa la cantidad.
5. Opcionalmente agrega motivo, área o proyecto.
6. Toca **Save** para confirmar.

El stock del producto se actualiza inmediatamente.

### Scan Count (Conteo por escaneo)

Desde la pantalla de Movimientos, toca el botón **Scan Count** para iniciar un conteo individual escaneando productos uno a uno:

1. Escanea o selecciona un producto.
2. Ingresa la cantidad contada físicamente.
3. Repite para cada producto.
4. Al terminar, toca **Save count result** (si todo cuadra) o **Approve N adjustments** (si hay diferencias — esto aplica los ajustes al inventario).

El conteo queda guardado en el historial.

### Historial de movimientos

La lista principal de la pestaña Movimientos muestra los últimos 50 movimientos del laboratorio, ordenados del más reciente al más antiguo, con tipo, producto, cantidad y fecha.

---

## 7. Conteo de inventario

La pestaña **Count** (Weekly Count) sirve para hacer un conteo físico completo del inventario.

### ¿Cómo funciona?

1. Toca **Start Count Session**.
2. La app carga todos los productos activos con su cantidad actual según el sistema.
3. Para cada producto, ingresa la cantidad que encontraste físicamente.
4. Al finalizar, la app compara lo esperado vs. lo contado y muestra las discrepancias.
5. Toca **Approve adjustments** para aplicar las diferencias al inventario, o **Save without adjusting** para guardar el conteo sin modificar el stock.

### Resultado del conteo

Cada sesión de conteo guarda:
- Fecha y hora del conteo
- Total de productos contados
- Número de discrepancias encontradas
- Detalle por producto: cantidad esperada, cantidad contada y diferencia

Puedes revisar el historial de conteos desde **Reportes → History**.

> **Frecuencia recomendada:** Para laboratorios que no registran movimientos individuales, se recomiendan conteos semanales o mensuales para mantener el inventario actualizado.

---

## 8. Reportes

La pestaña **Reports** tiene dos niveles: el reporte de estado actual y tres reportes de análisis histórico.

### Reporte de estado (pantalla principal)

Muestra una fotografía del inventario en el momento actual:

- **KPIs:** total de productos, alertas activas, productos en reorden
- **Out of Stock** — productos sin stock
- **Critical Stock** — productos por debajo del mínimo
- **Reorder Needed** — productos bajo el punto de reorden
- **Expiring Soon** — lotes próximos a vencer
- **Full Inventory** — lista completa con cantidad y estado de cada producto

Acciones disponibles:
- **Sync to Google Sheets** (ícono tabla) — exporta el inventario actual a una hoja de cálculo de Google.
- **Share via email** — genera un texto del reporte y lo abre en el cliente de correo para compartir.

### Reportes de análisis (cards de acceso rápido)

Toca cualquiera de las tres cards debajo del encabezado:

---

#### Consumption (Consumo)

Muestra cuánto se ha consumido de cada producto en un período determinado, **basado en movimientos de salida registrados**.

- Selecciona el período con los chips: **Last 7 days**, **Last 30 days**, **Last 90 days**.
- Los productos aparecen ordenados de mayor a menor consumo.
- Cada fila muestra el total consumido, la unidad y cuántos movimientos individuales lo componen (badge `×N`).
- La barra de progreso es proporcional al producto más consumido.

> Si el laboratorio no registra salidas individuales, esta pantalla aparecerá vacía con una guía para empezar a hacerlo.

---

#### Trend (Tendencia de inventario)

Muestra cómo ha evolucionado el inventario físico a lo largo de los últimos conteos, **basado en sesiones de conteo guardadas**.

- La tabla tiene una columna por sesión de conteo (máx. 4 sesiones recientes, de más antiguo a más reciente).
- La columna **Change** muestra la diferencia entre el primer y el último conteo registrado para ese producto:
  - Rojo con `−` → consumo (bajó la cantidad)
  - Verde con `+` → incremento (subió la cantidad)
- Los productos que no fueron contados en una sesión aparecen con `—`.

> Este reporte es útil tanto para laboratorios que registran movimientos como para los que solo hacen conteos periódicos. El "Change" permite inferir el consumo entre períodos.

---

#### History (Historial de conteos)

Lista todas las sesiones de conteo guardadas, del más reciente al más antiguo.

- Toca cualquier sesión para expandirla y ver el detalle por producto.
- La vista expandida muestra: producto, cantidad esperada, cantidad contada y badge de diferencia (verde = sin discrepancia, rojo = faltante, amarillo = sobrante).

---

## 9. Configuración

Accede desde el ícono de engranaje en el Dashboard (esquina superior derecha).

### Laboratorio

Muestra el nombre del laboratorio activo y tu rol (Admin / Member).

- **Switch laboratory** — regresa al selector de laboratorio para cambiar a otro laboratorio de tu cuenta.

### Categorías

Agrupa los productos por tipo (ej. Reactivos, Equipos, Materiales de limpieza).

- Toca **+ Add category** para crear una.
- Toca el ícono de editar (lápiz) para renombrarla.
- Toca el ícono de eliminar (basurero) para borrarla.

> Las categorías eliminadas no afectan los productos que ya las tenían asignadas.

### Ubicaciones

Define los lugares de almacenamiento del laboratorio (ej. Refrigerador 1, Armario A, Bodega).

- Misma operación que Categorías.

### Proveedores

Catálogo de proveedores con nombre, correo y teléfono de contacto.

- Toca **+ Add supplier** para crear uno.
- Completa nombre (obligatorio), correo y teléfono (opcionales).
- Editar y eliminar funcionan igual que en las demás secciones.

### Condiciones de almacenamiento

Define condiciones específicas de almacenamiento que puedes asignar a productos.

- **Nombre** — etiqueta descriptiva (ej. "Refrigeración 2–8 °C")
- **Temp min / Temp max** — rango de temperatura en °C (opcional)
- **Humedad máx.** — humedad máxima en % (opcional)
- **Sensible a la luz** — activa este toggle si el producto debe protegerse de la luz

### Alertas

Configura cuándo deseas recibir notificaciones:

- **Expiry alert days** — cuántos días antes del vencimiento quieres una alerta (puedes agregar múltiples valores, ej. 30, 60, 90 días)
- **Reorder notifications** — activa/desactiva alertas cuando un producto llega al punto de reorden
- **Critical stock notifications** — activa/desactiva alertas cuando un producto llega al nivel crítico

Toca **Save** para confirmar los cambios.

---

## 10. Escaneo de código de barras

LabTrack puede leer códigos de barras y QR en varias partes de la app:

| Dónde | Para qué |
|-------|----------|
| Inventario (AppBar) | Buscar un producto por código |
| Formulario de producto | Asignar código de barras al producto |
| Registro de movimiento | Seleccionar el producto a mover |
| Scan Count | Contar productos escaneándolos uno a uno |

Al tocar el ícono de escáner, la app solicita permiso de cámara la primera vez. Enfoca el código y la app lo lee automáticamente.

---

## 11. Sincronización y uso sin conexión

LabTrack funciona completamente sin conexión a internet. Todos los datos se guardan localmente en tu dispositivo.

Cuando hay conexión disponible, la app sincroniza automáticamente:

- Al abrir la pestaña de Inventario
- Después de registrar un movimiento
- Al guardar una sesión de conteo

La sincronización es bidireccional: los cambios que hagas en un dispositivo aparecen en los demás dispositivos del mismo laboratorio una vez que ambos estén en línea.

> **Tip:** Si trabajas en equipo, es buena práctica que cada integrante sincronice al inicio y al final de su turno para evitar conflictos de datos.

---

## 12. Dos tipos de laboratorio

LabTrack se adapta a dos flujos de trabajo distintos:

### Laboratorio con registro de movimientos

El equipo registra cada entrada, salida y devolución en tiempo real.

**Ventajas:**
- El inventario siempre refleja el estado actual sin necesidad de conteos frecuentes.
- El reporte de **Consumo** muestra exactamente cuánto se usó de cada producto.
- Los conteos periódicos sirven para **auditoría**: comparar lo que el sistema dice vs. lo que hay físicamente (discrepancias).

**Flujo recomendado:**
1. Registra entradas cuando llega mercancía.
2. Registra salidas cada vez que se consume un producto.
3. Haz un conteo mensual para detectar diferencias.
4. Revisa el reporte de Consumo para analizar tendencias.

---

### Laboratorio con conteos periódicos

El equipo no registra movimientos individuales; en cambio, hace conteos regulares del inventario completo.

**Ventajas:**
- Requiere menos disciplina en el día a día.
- Útil cuando el consumo es muy frecuente y registrarlo individualmente sería impracticable.

**Flujo recomendado:**
1. Haz un conteo semanal o mensual desde la pestaña **Count**.
2. Aprueba los ajustes al final del conteo para que el sistema refleje la realidad.
3. Revisa el reporte de **Trend** para ver cómo evolucionó el inventario entre conteos e inferir el consumo del período.

---

## Glosario

| Término | Significado |
|---------|-------------|
| **Lote** | Conjunto de un producto identificado por número de lote y fecha de vencimiento |
| **FEFO** | First Expired, First Out — el sistema ordena los lotes de menor a mayor fecha de vencimiento |
| **Stock mínimo** | Nivel por debajo del cual el stock es crítico |
| **Punto de reorden** | Nivel preventivo que indica que es hora de pedir más producto |
| **Tracks lots** | Propiedad del producto que indica si su stock se controla por lotes individuales |
| **Cantidad directa** | Valor de stock directo para un producto que no usa lotes |
| **Discrepancia** | Diferencia entre la cantidad esperada (sistema) y la cantidad contada físicamente |
| **Sincronización** | Proceso de puesta en coherencia entre la base de datos local del dispositivo y el servidor en la nube |

---

*LabTrack está desarrollado con Flutter + Supabase.*
