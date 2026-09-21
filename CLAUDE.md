# Directivas de Proyecto — Frescorden

## Habilidades y Protocolos de Desarrollo
- **Context7 (find-docs)**: Utilizar `ctx7` bajo demanda únicamente cuando existan dudas sobre métodos o APIs de paquetes en `pubspec.yaml`.
- **Sequential Thinking**: Aplicar resolución iterativa paso a paso para lógica compleja (Firestore, Provider, Clean Architecture).
- **Superpowers**: Trabajar mediante micro-iteraciones con verificación constante (`flutter analyze` y `flutter test`).
- **Code Simplifier**: Realizar una pasada de refactorización al finalizar un módulo importante para eliminar código redundante y comentarios de desarrollo.

## Reglas de Código y Calidad
- **Verificación**: Correr `flutter analyze` tras cada modificación (y `flutter test` antes de dar por cerrado un cambio de alcance medio/grande).
- **Moneda**: Todos los importes financieros deben usar `intl` con formato COP (`$ 65.000 COP`).
- **Clean Architecture**: Respetar la separación estricta (Data, Domain, Presentation). Prohibido comentarios del tipo `// FASE X`.
- **Commits**: Formato Conventional Commits (`feat:`, `fix:`, `refactor:`).
- **Versionamiento Semántico**: Incrementar el número de versión MINOR/PATCH y el build number en `pubspec.yaml` al cerrar cada Fase o entregar correcciones clave (formato X.Y.Z+N).
- **Colores**: Nunca `Colors.grey`/`Colors.black`/`Colors.white` fijos en widgets de UI — usar siempre `Theme.of(context).colorScheme.*`. Los `TextField` heredan estilo de `AppTheme.inputDecorationTheme`; no fijar `fillColor`/`border` por pantalla (rompe el tema oscuro).

## Git — Flujo y Propiedad
- Flujo de ramas: `dev` (trabajo diario) → `preprod` (PR) → `main` (PR). Guía paso a paso para el usuario en `docs/GUIA_GIT_RAMAS.txt` (local, no versionado).
- **La usuaria es la única que hace `git commit`/`git push`.** Claude edita archivos y deja los cambios sin commitear; nunca ejecuta commit/push por su cuenta salvo que se lo pidan explícitamente en ese momento puntual.
- No usar `git add -A`/`.` a ciegas: revisar qué se va a incluir.

## Assets e Íconos
- Identidad visual en `assets/Frescorden-logo/` (ícono de app, stickers, banners) y `assets/iconos/` (categorías de alimentos, acciones del FAB, recetas — con variantes chicas en `iconos/pequenos/`). Preferir estos sobre `Icons.*` de Material cuando exista un equivalente de marca.
- **Gotcha de pubspec.yaml**: `assets:` NO incluye subcarpetas automáticamente — cada subcarpeta nueva (`stickers/`, `banners/`, `pequenos/`, etc.) se declara aparte o Flutter no la empaqueta (`Unable to load asset`).
- Cambios de ícono de la app: `flutter_launcher_icons` (config en `pubspec.yaml`) — correr `dart run flutter_launcher_icons` tras cambiar la fuente y volver a compilar.

---
name: apa-ieee-report-generator
description: Redacción, estructuración y formateo de informes técnicos y académicos aplicando normativas APA (7.ª edición) e IEEE. Activa esta habilidad cuando el usuario solicite redactar, estructurar o formatear documentos formales, monografías o artículos técnicos.
---

# SKILL: Generador de Informes Técnicos y Académicos (APA 7 & IEEE)

Actúa como un experto en redacción científica, técnica y metodológica. Tu objetivo es redactar, estructurar y formatear documentos formales aplicando estrictamente las normativas de APA (7.ª edición) o IEEE, según el formato que el usuario te indique al inicio de la tarea.

## DIRECTRICES GENERALES PARA AMBOS FORMATOS
- Analiza minuciosamente las capturas de pantalla, datos o borradores proporcionados.
- Nunca inventes datos técnicos; si falta información en las imágenes o notas, haz suposiciones razonables de carácter técnico y menciónalas brevemente.
- Mantén un tono formal, objetivo, técnico y sin relleno comercial.

---

## MODO A: APLICACIÓN DE NORMAS APA (7.ª Edición)
Usa este formato cuando el usuario pida explícitamente "APA" o "APA 7".

1. **Estructura del Documento:**
   - Portada formal (Título, autor, afiliación, curso/institución, fecha). Paginación numérica desde la portada en la esquina superior derecha.
   - Tabla de Contenido (Índice general).
   - Lista de Figuras (Índice de imágenes o capturas).
   - Cuerpo del documento estructurado con la jerarquía de títulos de APA 7 (Niveles 1 al 5 según corresponda).
   - Referencias bibliográficas al final.

2. **Formato Estricto de Figuras (Capturas de pantalla / Imágenes):**
   Toda imagen o captura debe formatearse obligatoriamente así:
   - **Figura [Número]** (en negrita, línea independiente).
   - *Descripción breve de la figura* (en cursiva, debajo del número).
   - [La imagen o la representación de la captura].
   - Nota opcional al pie de la figura si requiere aclaración contextual.

3. **Estilo de Redacción:**
   - Interlineado conceptual doble, uso de fuentes estándar (Times New Roman 12 pt o Arial 11 pt).

---

## MODO B: APLICACIÓN DE FORMATO IEEE
Usa este formato cuando el usuario pida explícitamente "IEEE" (ideal para artículos científicos, ingeniería y tecnología).

1. **Estructura del Documento:**
   - Cabecera en formato IEEE: Título principal en la parte superior, seguido de los nombres de los autores, sus afiliaciones y correos electrónicos institucionales en formato de bloque o columnas.
   - Abstract (Resumen ejecutivo de 150 a 250 palabras) y Keywords (Palabras clave).
   - Cuerpo del documento redactado estrictamente en **dos columnas** (simulado mediante estructura de texto clara) o secciones numeradas de tipo académico (I. Introducción, II. Desarrollo / Metodología, III. Resultados, IV. Conclusiones).
   - Referencias bibliográficas numeradas entre corchetes al final (Ej: [1], [2]), citadas en orden de aparición en el texto.

2. **Formato Estricto de Figuras y Tablas en IEEE:**
   - Las figuras se enumeran con números romanos (Ej: **Fig. 1** o **Figura 1**).
   - El título y la descripción de la figura van **debajo** de la misma, abreviados y centrados (Ej: *Fig. 1. Pantalla de configuración inicial de red.*).
   - Las tablas llevan el título en la **parte superior** (Ej: *TABLE I. PARÁMETROS DE CONFIGURACIÓN*).

---

## FORMATO DE ENTREGA
- Pregunta o detecta automáticamente si el usuario prefiere **APA 7** o **IEEE** antes de redactar si la solicitud es ambigua.
- Entrega el texto estructurado con etiquetas Markdown claras (`#`, `##`, `###`) para que el usuario pueda copiarlo y pegarlo directamente en su procesador de textos (Word / LaTeX) sin perder la jerarquía.