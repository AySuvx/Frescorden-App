# Changelog

Registro de las versiones de FRESCORDEN, basado en el historial real de commits del repositorio (`AySuvx/Frescorden-App`). Formato inspirado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

## [1.19.0] - 2026-10-16

### Added
- Inclusión del plan Blaze de Firebase y preparación de la prueba piloto temporal.

### Changed
- Ampliación de pruebas unitarias y mejoras visuales generales.

## [1.18.0] - 2026-10-14

### Fixed
- Corrección de errores menores y mejoras visuales/prácticas detectadas tras la Iteración 4.

## [1.17.3] - 2026-09-21

### Changed
- Reorganización del flujo de navegación de la app.

## [1.17.0] - 2026-09-20

### Added
- Integración de reconocimiento de productos con IA en el módulo de agregar productos, junto con mejoras generales al módulo.

## [1.16.0] - 2026-09-20

### Added
- Integración de la identidad visual de la mascota Frescorden en toda la app.

### Changed
- Reorganización de `lib/screens/` y `lib/Widgets/` hacia `lib/presentation/`; `AuthProvider` reemplaza el acceso directo a `FirebaseAuth.instance.currentUser` en 3 pantallas; `ProductFreshness` se extrae a `domain/entities/`.

### Fixed
- Corrección del servicio de notificaciones.

### Removed
- Limpieza de archivos sueltos (imagen de prueba, carpeta `docs/` obsoleta).

## [1.15.0] - 2026-09-17

### Added
- Suite de pruebas BDD.

## [1.14.0] - 2026-09-17

### Added
- Cierre del Módulo 2 (Fase 6): ProGuard/R8, reglas de Firestore y hardening del asistente de IA.

### Fixed
- El comentario de `EnableImpeller` ya no depende del SHA del commit; corrección de la versión mostrada en "Acerca de".

## [1.13.0] - 2026-09-16

### Changed
- Cierre del Módulo 1 (Fase 6): limpieza general de comentarios de desarrollo (sin cambios funcionales) en config/theme, domain/entities, data/datasources, data/repositories, presentation/providers, presentation/utils y widgets/screens.
- `AnalyticsSummary.hasWasteData` sustituye un chequeo inline duplicado.

### Removed
- `HouseholdModel.fromEntity` (código muerto, sin llamadores).

## [1.12.0] - 2026-09-16

### Added
- Modo cocina.

### Fixed
- Corrección de deduplicación.

## [1.11.0] - 2026-09-16

### Changed
- Pulido visual premium (glassmorphism y física de resortes) en toda la UI.

## [1.9.1] - 2026-09-11

### Added
- Splash screen, onboarding e interacciones hápticas.

## [1.8.0] - 2026-09-11

### Changed
- Primera tanda de mejoras visuales.

## [1.7.1] - 2026-09-11

### Changed
- Segunda tanda de mejoras generales de UI.

## [1.7.0] - 2026-09-11

### Added
- Avisos de MIUI (permisos agresivos de batería), enlaces a YouTube y vista de plato equilibrado.

## [1.4.0] - 2026-09-07

### Added
- Módulo de grupos familiares (households) con sincronización en tiempo real.
- Motor de recetas inteligentes conectado al inventario dinámico mediante IA.
- Persistencia offline, notificaciones locales y sanitización de datos del inventario.
- Reglas de negocio para el asistente culinario.

Entre la Entrega 0 y esta versión también se incorporaron: capa Clean Architecture para Auth, Product, Recipes y Shopping; categorización de alimentos y alertas de stock mínimo; historial y KPIs de analíticas (Fase 3) con gráficos de `fl_chart`; presupuesto y personas dinámicos con formateo de moneda vía `intl`; fecha de vencimiento opcional para registro a granel; permiso `POST_NOTIFICATIONS` (Android 13+); exención de batería y acceso a autoinicio para ROMs agresivas; y varias correcciones (tipado de `ProductProvider`, desbordamientos de UI, guardado duplicado al editar productos, orden de moneda, chequeo de alarma exacta).

## [1.0.0] - 2026-05-31

### Changed
- **Entrega 0**: reestructuración completa a Clean Architecture (separación en capas `data`/`domain`/`presentation`) sobre el código funcional heredado del mockup inicial (desarrollado entre febrero y agosto de 2025 bajo el tag `v1.0`–`v1.3.4` del repositorio predecesor).

---

## [Unreleased]

Trabajo posterior a 1.19.0+26 (sin bump de versión todavía): ampliación adicional de pruebas unitarias y arreglo de fallos menores (commits `7ca640b`, `3abfb30`, `5c9344d`).
