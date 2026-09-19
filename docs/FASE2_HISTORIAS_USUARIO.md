# Fase 2 — Historias de Usuario y Backlog de Jira

**Proyecto:** Frescorden — Gestión integral de alimentos en el hogar
**Universidad:** Universidad de Cundinamarca (UDEC)
**Rol de elaboración:** Scrum Master & Lead Agile Analyst
**Marco de trabajo:** Scrum + XP (Extreme Programming)
**Cronograma institucional aprobado:** 14 de agosto — 30 de octubre de 2026
**Desarrolladores del Proyecto:** Bryann Steven Gomez Ramirez, Johan Stiven Otalora Buitrago

---

## Nota metodológica y hallazgo de auditoría

Esta especificación deriva 1:1 de los Requerimientos Funcionales de la Fase 1 (`FASE1_REQUERIMIENTOS.md`). Al cruzar el cronograma oficial de sprints contra el historial real de commits del repositorio, se encontraron dos desviaciones que se documentan aquí por transparencia y trazabilidad, en vez de ocultarse:

1. **El código se adelantó al plan.** Las 6 Historias de Usuario, más las pruebas BDD/Widget y el hardening de seguridad, ya estaban 100% implementadas y verificadas el **16-17 de septiembre de 2026** — hasta 3 semanas antes de la fecha en que el cronograma oficial las agenda (Sprint 3 y Sprint 4, hasta el 16 de octubre). El detalle por historia está en la tabla de la sección 3.
2. **La documentación formal se atrasó respecto al plan.** El Sprint 1 (Análisis y Diseño, 22 ago-4 sep) es donde debía producirse la Especificación de Requisitos, pero esta se entregó formalmente hasta el **17 de septiembre de 2026** — es decir, la documentación quedó rezagada mientras el desarrollo iba adelantado.

**Decisión adoptada:** las fechas de *Start Date* / *End Date* de cada Sprint en este documento y en `jira_import.csv` respetan exactamente el cronograma institucional aprobado (no se alteran para "cuadrar" con la realidad). Cada issue incluye además su **estado real** y su **fecha real de finalización**, de modo que el backlog sea auditable sin contradecir el cronograma entregado a la universidad.

Los períodos **14-21 de agosto** y **24-30 de octubre** son colchón institucional (fuera de sprint, sin historias asignadas) y se documentan como tales en la sección 4.

**Nota sobre Story Points:** al estar el código ya construido al momento de escribir este backlog, los puntos de historia se asignaron según la complejidad real observada (ramas de código, dependencias externas, casos borde cubiertos en las pruebas), no mediante una sesión de Planning Poker previa a la implementación. Es una estimación retrospectiva, no prospectiva — útil para dimensionar el backlog y compararlo con futuras iteraciones, pero no debe presentarse como evidencia de que el equipo estimó bajo incertidumbre antes de programar.

---

## 1. Historias de Usuario

### Historia de Usuario: HU01

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU01 | **Usuario:** | Usuario del Hogar |
| **Nombre historia:** | Gestión de Inventario y Control de Caducidad | | |
| **Prioridad en negocio:** | Alta | **Riesgo en desarrollo:** | Bajo |
| **Puntos estimados:** | 5 | **Iteración asignada:** | Sprint 2 |
| **Programador responsable:** | Bryann Steven Gomez Ramirez – Johan Stiven Otalora Buitrago | | |

**Descripción:** Como miembro de un hogar, quiero registrar mis alimentos y ver su estado de vencimiento clasificado automáticamente, para evitar el desperdicio de comida y saber qué tengo disponible en todo momento.

**Observaciones:**
- **Dado** un inventario con fechas de caducidad variadas, **cuando** consulto la lista de productos, **entonces** se clasifican en Fresco / Por vencer (≤ 3 días) / Vencido, y los próximos a vencer se priorizan visualmente.
- **Dado** que voy a agregar un producto, **cuando** su código de barras o nombre ya existe en el hogar, **entonces** el sistema lo detecta antes de crear un duplicado.
- **Dado** que otro miembro de mi hogar modifica el inventario, **cuando** yo tengo la app abierta, **entonces** veo el cambio reflejado en tiempo real sin recargar.
- *Nota técnica:* sincronización en tiempo real vía Cloud Firestore (ver Fase 3, Diagrama de Componentes). Cobertura de pruebas: 5 escenarios BDD automatizados, sin hallazgos de auditoría pendientes.

---

### Historia de Usuario: HU02

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU02 | **Usuario:** | Usuario del Hogar |
| **Nombre historia:** | Algoritmo de Coincidencia de Recetas | | |
| **Prioridad en negocio:** | Alta | **Riesgo en desarrollo:** | Bajo |
| **Puntos estimados:** | 5 | **Iteración asignada:** | Sprint 3 |
| **Programador responsable:** | Johan Stiven Otalora Buitrago – Bryann Steven Gomez Ramirez | | |

**Descripción:** Como usuario, quiero ver qué recetas puedo preparar con lo que ya tengo en mi inventario, para decidir qué cocinar sin necesidad de salir a comprar todo desde cero.

**Observaciones:**
- **Dado** un listado de insumos del hogar, **cuando** se calcula el match de cada receta, **entonces** se asigna el porcentaje exacto de coincidencia y el indicador visual verde/ámbar correspondiente.
- **Dado** el catálogo completo de recetas, **cuando** se ordena por disponibilidad, **entonces** ninguna receta se oculta, solo se reordenan de mayor a menor coincidencia.
- *Nota técnica:* cálculo determinístico en memoria, sin dependencias externas — el riesgo de desarrollo es bajo. Base del caso de uso «extends» de HU03 en el Diagrama de Casos de Uso (Fase 3).

---

### Historia de Usuario: HU03

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU03 | **Usuario:** | Usuario del Hogar |
| **Nombre historia:** | Generación Culinaria con IA (Gemini API) | | |
| **Prioridad en negocio:** | Media | **Riesgo en desarrollo:** | Alto |
| **Puntos estimados:** | 8 | **Iteración asignada:** | Sprint 3 |
| **Programador responsable:** | Bryann Steven Gomez Ramirez – Johan Stiven Otalora Buitrago | | |

**Descripción:** Como usuario, quiero que la app me sugiera algo nuevo para cocinar cuando ninguna de mis recetas guardadas me sirva con lo que tengo en casa, para no quedarme sin ideas de qué cocinar.

**Observaciones:**
- **Dado** que el mejor porcentaje de coincidencia del catálogo es menor al 50%, **cuando** el usuario solicita una receta con IA, **entonces** el sistema envía el inventario disponible a Gemini y muestra una receta colombiana generada dinámicamente.
- **Dado** que la respuesta de Gemini no es un JSON válido, **cuando** el sistema intenta procesarla, **entonces** se captura como error controlado en vez de romper la pantalla.
- *Nota técnica:* riesgo Alto justificado por la dependencia de un servicio externo no determinista. Mitigaciones de seguridad aplicadas: truncamiento del texto enviado a 4000 caracteres y deserialización segura de la respuesta (ver RNF01, Fase 1).

---

### Historia de Usuario: HU04

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU04 | **Usuario:** | Usuario del Hogar |
| **Nombre historia:** | Envío a Lista de Compras y Deduplicación de Insumos Faltantes | | |
| **Prioridad en negocio:** | Alta | **Riesgo en desarrollo:** | Medio |
| **Puntos estimados:** | 5 | **Iteración asignada:** | Sprint 4 |
| **Programador responsable:** | Johan Stiven Otalora Buitrago – Bryann Steven Gomez Ramirez | | |

**Descripción:** Como usuario, quiero agregar a mi lista de compras lo que me falta de una receta con un solo toque, para no tener que escribirlo a mano ni revisar si ya lo había anotado antes.

**Observaciones:**
- **Dado** un ítem existente en la canasta, **cuando** se agregan ítems desde una receta, **entonces** se aplica deduplicación estricta e insensible a mayúsculas/minúsculas.
- **Dado** que aún no ha cargado la canasta base (contenido local estático, no Firestore), **cuando** se agregan ingredientes faltantes de una receta, **entonces** no se pierden ni se duplican una vez la canasta termina de cargar.
- **Dado** un nivel de presupuesto elegido, **cuando** se calcula el costo de lo faltante, **entonces** se compara contra el techo de ese nivel.
- *Nota técnica:* riesgo Medio — durante el desarrollo se encontró y corrigió una condición de carrera real (agregar ítems antes de que la canasta base termine de cargar). **Hallazgo de arquitectura vigente** (ver Fase 3, sección 6): los ítems agregados por el usuario viven solo en el estado de la sesión activa — no se persisten ni se comparten entre miembros del hogar.

---

### Historia de Usuario: HU05

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU05 | **Usuario:** | Usuario del Hogar |
| **Nombre historia:** | Modo Cocina Interactivo | | |
| **Prioridad en negocio:** | Media | **Riesgo en desarrollo:** | Bajo |
| **Puntos estimados:** | 2 | **Iteración asignada:** | Sprint 3 |
| **Programador responsable:** | Bryann Steven Gomez Ramirez – Johan Stiven Otalora Buitrago | | |

**Descripción:** Como usuario, quiero marcar los pasos de una receta como completados mientras cocino, para seguir mi progreso sin perder el hilo de la preparación.

**Observaciones:**
- **Dado** que estoy en el detalle de una receta, **cuando** toco un paso de preparación, **entonces** se marca como completado con retroalimentación háptica inmediata.
- **Dado** un paso ya marcado, **cuando** lo toco de nuevo, **entonces** se desmarca (el estado no se persiste en ningún almacenamiento, es solo apoyo visual durante la cocción).
- *Nota técnica:* estado local transitorio, sin persistencia ni dependencias externas — el riesgo de desarrollo es mínimo.

---

### Historia de Usuario: HU06

| Campo | Valor | Campo | Valor |
| :--- | :--- | :--- | :--- |
| **Número:** | HU06 | **Usuario:** | Usuario del Hogar / Administrador |
| **Nombre historia:** | Gestión Multiusuario y Administración de Hogares | | |
| **Prioridad en negocio:** | Alta | **Riesgo en desarrollo:** | Medio |
| **Puntos estimados:** | 8 | **Iteración asignada:** | Sprint 2 |
| **Programador responsable:** | Johan Stiven Otalora Buitrago – Bryann Steven Gomez Ramirez | | |

**Descripción:** Como administrador de un hogar, quiero poder sacar a alguien del hogar si ya no debería tener acceso, para que mi inventario y mi lista de compras se sigan compartiendo solo con quien corresponde.

**Observaciones:**
- **Dado** que soy administrador del hogar, **cuando** expulso a otro miembro, **entonces** la operación se completa exitosamente.
- **Dado** que soy un miembro regular, **cuando** intento expulsar a otro miembro, **entonces** el sistema lo bloquea con un error de permisos controlado.
- **Dado** que soy administrador, **cuando** intento expulsarme a mí mismo o abandonar mi propio hogar, **entonces** el sistema lo bloquea (un hogar no puede quedar sin administrador).
- **Dado** que soy un miembro regular, **cuando** decido abandonar el hogar, **entonces** la operación se completa exitosamente.
- *Nota técnica:* riesgo Medio por la matriz de permisos (administrador/miembro regular) y la sincronización multi-dispositivo en tiempo real. En el Diagrama de Casos de Uso (Fase 3), el rol Administrador se modela como una especialización del actor Usuario del Hogar.

---

## 2. Estado real de implementación (auditoría contra `git log`)

| HU | Sprint planeado | Rango planeado | Fecha real de finalización | Estado |
|---|---|---|---|---|
| HU06 | Sprint 2 | 5-18 sep | 2026-09-07 | ✅ Done (adelantado) |
| HU01 | Sprint 2 | 5-18 sep | 2026-08-30 | ✅ Done (adelantado) |
| HU02 | Sprint 3 | 19 sep-2 oct | 2026-09-07 | ✅ Done (adelantado) |
| HU03 | Sprint 3 | 19 sep-2 oct | 2026-09-08 (hardening 2026-09-17) | ✅ Done (adelantado) |
| HU05 | Sprint 3 | 19 sep-2 oct | 2026-09-16 | ✅ Done (adelantado) |
| HU04 | Sprint 4 | 3-16 oct | 2026-08-30 (fix dedup 2026-09-16) | ✅ Done (muy adelantado) |
| Pruebas BDD/Widgets (RNF04) | Sprint 4 | 3-16 oct | 2026-09-17 | ✅ Done (adelantado) |
| Seguridad (RNF01/RNF02) | Sprint 4 | 3-16 oct | 2026-09-17 | ✅ Done (adelantado) |
| Piloto con usuarios y evaluación | Sprint 5 | 17-23 oct | *Pendiente* | ⏳ To Do |

---

## 3. Tabla de asignación temporal (cronograma oficial)

| Sprint | Rango de fechas | Contenido |
|---|---|---|
| Sprint 1 | 22 ago - 4 sep | Análisis y Diseño (Fase 1: RF01-RF06, RNF01-RNF04) |
| Sprint 2 | 5 - 18 sep | HU06 (Gestión Multiusuario), HU01 (Inventario de Alimentos) |
| Sprint 3 | 19 sep - 2 oct | HU02 (Coincidencia de Recetas), HU03 (IA Gemini), HU05 (Modo Cocina) |
| Sprint 4 | 3 - 16 oct | HU04 (Lista de Compras), Pruebas BDD/Widgets, Seguridad |
| Sprint 5 | 17 - 23 oct | Piloto con usuarios y evaluación |

## 4. Colchón institucional (fuera de sprint)

| Periodo | Naturaleza |
|---|---|
| 14 - 21 agosto | Holgura previa al Sprint 1 — sin historias asignadas |
| 24 - 30 octubre | Holgura posterior al Sprint 5 — cierre, evaluación final y ajustes de monografía |
