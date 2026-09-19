# Fase 1 — Especificación de Requisitos de Software

**Proyecto:** Frescorden — Gestión integral de alimentos en el hogar
**Universidad:** Universidad de Cundinamarca (UDEC)
**Tipo de documento:** Especificación de Requerimientos Funcionales (RF) y No Funcionales (RNF)

> **Nota metodológica:** el proyecto se desarrolló bajo **Scrum + XP (Extreme Programming)**. A diferencia de un enfoque en cascada, XP no exige una especificación exhaustiva previa a la codificación: sus prácticas centrales (diseño simple, refactorización continua, pruebas constantes) permiten que el entendimiento del dominio madure junto con el código. Los Módulos 1 (auditoría de Clean Code / refactorización) y 3 (pruebas BDD) de la Fase 6 de desarrollo son, en ese sentido, prácticas XP genuinas y no una reconstrucción posterior. Esta especificación fue elaborada y **validada contra la implementación existente**: cada requerimiento describe comportamiento verificado en el código fuente y en la suite de pruebas automatizadas. Se documenta con honestidad metodológica: los "Sprints" de la Fase 2 organizan retrospectivamente el trabajo ya construido — no hubo ciclos de planificación/demo/retro con un cliente real en cada límite de sprint, por lo que esta especificación formal no debe leerse como evidencia de que precedió al desarrollo, sino como su formalización de cierre.

---

## Requerimientos Funcionales (RF)

### RF01

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF01 |
| **Nombre del Requerimiento** | Gestión de Inventario y Control de Caducidad |
| **Características** | Permite al usuario registrar, consultar, actualizar y eliminar los alimentos de su hogar, con seguimiento automático de su estado de vencimiento. Actores involucrados: Usuario miembro de hogar, Sistema (cálculo de frescura). |
| **Descripción del requerimiento** | El sistema debe permitir registrar un alimento con nombre, cantidad, unidad y fecha de ingreso, y buscarlo por código de barras o por nombre exacto antes de crear un duplicado. El inventario del hogar se sincroniza en tiempo real entre todos sus miembros: un cambio hecho por cualquiera de ellos se refleja de inmediato en los demás dispositivos. Cada alimento se clasifica automáticamente en uno de tres estados de frescura (Fresco, Por vencer, Vencido) según los días restantes hasta su vencimiento, usando el umbral: 3 días o menos = "Por vencer", vencimiento ya pasado = "Vencido". Los alimentos próximos a vencer deben priorizarse visualmente sobre el resto del listado. Como salida, el sistema entrega el listado ordenado, el conteo de alimentos con bajo stock y su agrupación por categoría. |
| **Requerimiento NO funcional asociado** | RNF01, RNF03, RNF04 |
| **Prioridad del requerimiento** | Alta |

### RF02

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF02 |
| **Nombre del Requerimiento** | Algoritmo de Coincidencia de Recetas |
| **Características** | Calcula qué tan preparable es cada receta del catálogo según los insumos que el usuario ya tiene en su inventario. Actores involucrados: Usuario, Sistema (motor de coincidencia). |
| **Descripción del requerimiento** | Dado el inventario actual del hogar, el sistema calcula para cada receta del catálogo el porcentaje de ingredientes disponibles frente al total requerido, y determina la lista de ingredientes faltantes y si la receta está completamente disponible. El catálogo completo se ordena de mayor a menor porcentaje de coincidencia, sin ocultar recetas con baja disponibilidad. El porcentaje de la mejor receta disponible determina si se ofrece el fallback de generación con IA (RF03); antes de que el catálogo termine de cargar, este porcentaje se asume 100% para no ofrecer la IA prematuramente. El indicador visual de cada receta usa este porcentaje para mostrarse en verde (disponible) o ámbar (faltan ingredientes). |
| **Requerimiento NO funcional asociado** | RNF03, RNF04 |
| **Prioridad del requerimiento** | Alta |

### RF03

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF03 |
| **Nombre del Requerimiento** | Generación Culinaria con IA (Gemini API) |
| **Características** | Ofrece una receta generada por inteligencia artificial cuando ninguna receta del catálogo alcanza un umbral mínimo de coincidencia con el inventario. Actores involucrados: Usuario, Asistente de IA (Gemini). |
| **Descripción del requerimiento** | Cuando el mejor porcentaje de coincidencia del catálogo cae por debajo del umbral de disponibilidad (50%), el sistema ofrece generar una receta colombiana dinámicamente a través de un servicio externo de inteligencia artificial (Gemini API). Como entrada se envían los insumos disponibles del hogar; el texto enviado a la IA se limita a un máximo de 4000 caracteres, para evitar abuso de cuota y mitigar inyección de instrucciones. Si la respuesta de la IA llega en un formato inesperado o corrupto, el sistema lo captura como un error controlado, sin exponer una falla cruda al usuario. |
| **Requerimiento NO funcional asociado** | RNF01, RNF02 |
| **Prioridad del requerimiento** | Media |

### RF04

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF04 |
| **Nombre del Requerimiento** | Envío a Lista de Compras y Deduplicación de Insumos Faltantes |
| **Características** | Traslada a la Lista de Compras los ingredientes que le faltan al usuario para preparar una receta, evitando duplicados y calculando el costo frente al presupuesto elegido. Actores involucrados: Usuario, Sistema (motor de presupuesto). |
| **Descripción del requerimiento** | Desde el detalle de una receta, el usuario puede enviar con un solo toque sus ingredientes faltantes a la Lista de Compras. El sistema aplica deduplicación estricta e insensible a mayúsculas/minúsculas: si un ítem ya existe en la canasta (por nombre), se fusiona en vez de duplicarse, incluso si la canasta base del nivel de presupuesto elegido todavía no ha terminado de cargar en el momento del envío. La lista permite elegir un nivel de presupuesto, muestra únicamente lo que el usuario no tiene ya en inventario, y compara el costo estimado de lo faltante contra el techo del nivel elegido. Adicionalmente ofrece enlaces directos a supermercados colombianos (Éxito, Carulla, Olímpica) para comparar precios. **Nota de arquitectura (ver detalle técnico en Fase 3, sección 6):** los ítems agregados por el usuario a la lista viven únicamente en el estado de la sesión activa — no se persisten en ningún almacenamiento y no se comparten entre los demás miembros del hogar. |
| **Requerimiento NO funcional asociado** | RNF03, RNF04 |
| **Prioridad del requerimiento** | Alta |

### RF05

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF05 |
| **Nombre del Requerimiento** | Modo Cocina Interactivo |
| **Características** | Convierte los pasos de preparación de una receta en un checklist interactivo mientras el usuario cocina, en vez de texto plano estático. Actores involucrados: Usuario. |
| **Descripción del requerimiento** | En la pantalla de detalle de receta, cada paso de preparación puede marcarse y desmarcarse como completado con un toque, con retroalimentación háptica inmediata. Este progreso es un estado transitorio de apoyo durante la cocción, no un dato de negocio que deba conservarse tras salir de la pantalla. La misma vista expone, además, el acceso de un solo toque para enviar los ingredientes faltantes a la Lista de Compras (RF04). |
| **Requerimiento NO funcional asociado** | RNF03 |
| **Prioridad del requerimiento** | Media |

### RF06

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RF06 |
| **Nombre del Requerimiento** | Gestión Multiusuario y Administración de Hogares |
| **Características** | Permite que varios usuarios compartan un mismo inventario y lista de compras bajo el concepto de "Hogar" (Household), con un rol de administrador que controla la membresía. Actores involucrados: Usuario administrador, Usuario miembro regular. |
| **Descripción del requerimiento** | Un hogar tiene exactamente un administrador y una lista de miembros. El administrador puede expulsar a otro miembro, pero el sistema bloquea explícitamente que: (a) un miembro regular expulse a otro miembro, (b) el administrador se auto-expulse, y (c) el administrador abandone su propio hogar — en los tres casos la operación se rechaza con un error de permisos controlado. Un miembro regular sí puede abandonar el hogar libremente. El inventario y la actividad del hogar se sincronizan en tiempo real entre todos sus miembros. La lista de compras (RF04) **no** forma parte de esta sincronización: es estado local de cada dispositivo, no compartido entre miembros. |
| **Requerimiento NO funcional asociado** | RNF01, RNF03, RNF04 |
| **Prioridad del requerimiento** | Alta |

---

## Requerimientos No Funcionales (RNF)

### RNF01

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RNF01 |
| **Nombre del Requerimiento** | Seguridad de Datos (Firestore Rules) |
| **Características** | Atributo de calidad de **seguridad**: garantiza que ningún usuario pueda leer o modificar datos de un hogar del que no es miembro, ni escalar privilegios de administrador sin autorización. |
| **Descripción del requerimiento** | El acceso a las colecciones `users/` y `households/` en Firestore debe seguir el principio de denegación por defecto (`firestore.rules`): toda operación no explícitamente permitida se rechaza. Los prompts enviados a la API de Gemini se sanitizan (truncamiento a 4000 caracteres) para reducir la superficie de inyección de instrucciones, y las respuestas de IA se deserializan con manejo explícito de errores de formato en vez de asumir una estructura JSON confiable. Criterio de cumplimiento: cero accesos cruzados entre hogares distintos verificados en las reglas, y cero excepciones no controladas al parsear respuestas externas (IA o Firestore). |
| **Prioridad del requerimiento** | Alta |

### RNF02

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RNF02 |
| **Nombre del Requerimiento** | Eficiencia de Recursos y Protección del Binario de Distribución |
| **Características** | Atributo de calidad de **eficiencia** (uso de espacio de almacenamiento del paquete instalable) y de **protección del código distribuido** (resistencia a la decompilación), sin alterar el comportamiento funcional observable de la aplicación. |
| **Descripción del requerimiento** | El paquete de producción para Android debe reducir el tamaño de los recursos y clases no utilizadas, y ofuscar el código empaquetado, de forma que esto no altere el comportamiento en tiempo de ejecución. Criterio de cumplimiento: el build de producción compila exitosamente con la minimización, ofuscación y separación de información de depuración habilitadas, y la aplicación arranca y opera sin errores de clases faltantes ni fallos de componentes nativos causados por esa reducción. *(Mecanismo técnico empleado: R8/ProGuard — ver Fase 3, Diagrama de Despliegue, para el detalle de infraestructura.)* |
| **Prioridad del requerimiento** | Media |

### RNF03

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RNF03 |
| **Nombre del Requerimiento** | Arquitectura y Mantenibilidad (Clean Architecture) |
| **Características** | Atributo de calidad de **mantenibilidad**: separa el código en capas independientes para que el dominio del negocio no dependa de detalles de infraestructura (Firestore, IA, UI). |
| **Descripción del requerimiento** | El sistema debe organizarse en tres capas (`domain/`, `data/`, `presentation/`) con dirección de dependencia estricta: `presentation` depende de `domain`, `data` implementa las interfaces (`I*Repository`) definidas en `domain`, y `domain` no importa símbolos de Firebase ni de Flutter UI. Se aplican principios SOLID: una interfaz de repositorio por agregado (`IProductRepository`, `IShoppingRepository`, `IRecipeRepository`, `IHouseholdRepository`, entre otras 7 más), inversión de dependencias entre providers y repositorios, y extensión de comportamiento (p. ej. `ProductFreshness.fromDaysRemaining`) sin modificar código existente. Criterio de cumplimiento: ningún archivo bajo `lib/domain/` importa `package:cloud_firestore` ni `package:flutter/material.dart`. |
| **Prioridad del requerimiento** | Alta |

### RNF04

| Campo | Descripción |
|---|---|
| **Identificación del requerimiento** | RNF04 |
| **Nombre del Requerimiento** | Confiabilidad y Calidad de Código |
| **Características** | Atributo de calidad de **confiabilidad**: asegura que la lógica de negocio crítica (inventario, recetas, compras, hogares) se comporta correctamente ante los escenarios de prueba definidos, y que la interfaz renderiza sin excepciones. |
| **Descripción del requerimiento** | El sistema debe contar con pruebas automatizadas bajo el enfoque BDD (Given/When/Then) para la lógica de negocio de cada módulo, además de pruebas de interfaz que verifiquen el renderizado libre de excepciones de las pantallas principales con sus componentes reales. Criterio de cumplimiento: el 100% de las pruebas automatizadas definidas debe pasar en cada verificación, y el análisis estático del código no debe reportar incidencias — este criterio debe sostenerse a medida que se agreguen nuevas pruebas, no ser una cifra fija. *(Estado verificado al cierre de la Fase 6, Módulo 3: 29 de 29 pruebas pasando, 0 incidencias de análisis estático — evidencia puntual, no el criterio en sí.)* |
| **Prioridad del requerimiento** | Alta |

---

## Trazabilidad RF ↔ RNF

| RF | RNF asociados |
|---|---|
| RF01 — Gestión de Inventario y Control de Caducidad | RNF01, RNF03, RNF04 |
| RF02 — Algoritmo de Coincidencia de Recetas | RNF03, RNF04 |
| RF03 — Generación Culinaria con IA (Gemini API) | RNF01, RNF02 |
| RF04 — Envío a Lista de Compras y Deduplicación de Insumos Faltantes | RNF03, RNF04 |
| RF05 — Modo Cocina Interactivo | RNF03 |
| RF06 — Gestión Multiusuario y Administración de Hogares | RNF01, RNF03, RNF04 |
