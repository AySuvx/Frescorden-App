# Directivas de Proyecto — Frescorden

## Habilidades y Protocolos de Desarrollo
- **Context7 (find-docs)**: Utilizar `ctx7` bajo demanda únicamente cuando existan dudas sobre métodos o APIs de paquetes en `pubspec.yaml`.
- **Sequential Thinking**: Aplicar resolución iterativa paso a paso para lógica compleja (Firestore, Provider, Clean Architecture).
- **Superpowers**: Trabajar mediante micro-iteraciones con verificación constante (`flutter analyze` y `flutter test`).
- **Code Simplifier**: Realizar una pasada de refactorización al finalizar un módulo importante para eliminar código redundante y comentarios de desarrollo.

## Reglas de Código y Calidad
- **Verificación**: Correr `flutter analyze` tras cada modificación.
- **Moneda**: Todos los importes financieros deben usar `intl` con formato COP (`$ 65.000 COP`).
- **Clean Architecture**: Respetar la separación estricta (Data, Domain, Presentation). Prohibido comentarios del tipo `// FASE X`.
- **Commits**: Formato Conventional Commits (`feat:`, `fix:`, `refactor:`).
- **Versionamiento Semántico**: Incrementar el número de versión MINOR/PATCH y el build number en `pubspec.yaml` al cerrar cada Fase o entregar correcciones clave (formato X.Y.Z+N).
