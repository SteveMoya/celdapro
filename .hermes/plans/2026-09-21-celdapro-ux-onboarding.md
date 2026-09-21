# Plan — CeldaPro: experiencia de usuario (onboarding, animaciones y flujo)

> **Fecha:** 2026-09-21
> **Autor:** Roxy (asistente)
> **Estado:** ⏳ **Pendiente de aprobación de Steve**
> **Punto de partida:** v0.10.0 (M1–M6 + F0/F1/F4 de fase 2 hechos)
> **Petición de Steve:** onboarding con animaciones, animaciones de energía y carga,
> micro-interacciones en toda la aplicación, mejora del flujo del usuario, y este plan con su
> diagrama de flujo UI/UX.
> **Se antepone a:** F2 (packs) y F3 (degradación), que quedan esperando.

---

## 1. Diagnóstico: qué encontré (verificado en el código, no supuesto)

| Comprobación | Resultado |
|---|---|
| Animaciones en toda la app | **0**. Ni un `AnimationController` en 7 984 líneas de interfaz. |
| Onboarding / tutorial | **No existe**. El primer arranque cae en un resumen vacío. |
| Estados vacíos | **5**, todos con el mismo widget genérico: icono gris, un texto, y nada que hacer. |
| Pantallas | 4 secciones + 10 pantallas empujadas, sin transición propia. |
| Feedback táctil (vibración) | **0**. Ni un `HapticFeedback`. |

**El problema real, dicho sin adornos:** la app está construida **de dentro hacia fuera**. La capa de
datos es sólida (315 pruebas, migraciones probadas, paginación, respaldo). Pero la experiencia se fue
añadiendo por encima sin un plan, y eso se nota en tres sitios:

1. **Nadie le enseña el flujo al que abre la app por primera vez.** Un técnico con guantes en un
   taller tiene que *adivinar* que primero se dan de alta celdas, luego se miden, luego se etiquetan.
2. **La app abre en el sitio equivocado para un taller nuevo.** Abre en «Resumen», que con cero
   celdas no resume nada. El primer paso de verdad es registrar.
3. **Nada confirma lo que acaba de pasar.** Guardas una medición y la pantalla cambia en silencio.
   No sabes si se grabó hasta que vas a mirar. En un taller, eso genera dudas y doble trabajo.

---

## 2. El principio que voy a seguir (y por qué)

Steve pidió animaciones. Yo voy a hacerlas, pero con una regla que me parece importante decir en voz
alta antes de empezar:

> **La animación informa, no decora.**

En una app de taller, con prisa, con guantes y a veces con mala luz, una animación que estorba es
**peor que ninguna**. Cada animación que añada tiene que responder a esta pregunta: *¿qué me está
diciendo esto que antes no sabía?*

- ✅ **Sí**: la batería se llena hasta el nivel de SoH → me dice de un vistazo que está al 87 %.
- ✅ **Sí**: vibración corta al guardar → me confirma sin mirar la pantalla.
- ✅ **Sí**: la etapa avanza con un pulso de energía → me dice dónde estoy en el proceso.
- ❌ **No**: una transición de un segundo entre pantallas → solo me hace esperar.
- ❌ **No**: fuegos artificiales al terminar un lote → bonito una vez, molesto a la vigésima.

**Y una regla de respeto al usuario:** si el teléfono tiene activado «reducir animaciones» en
Accesibilidad, la app **las desactiva**. Quien lo activa suele tener una razón (mareo, sensibilidad
al movimiento). Lo trato como requisito, no como extra.

---

## 3. Las cuatro fases

### 🚀 G1 — Onboarding que enseña el oficio · v0.11.0

**Por qué:** hoy nadie explica el flujo. Es lo que más falta y lo más barato de arreglar.

- **Cuatro pantallas animadas**, no un muro de texto:
  1. **Bienvenida** — qué es CeldaPro, en una frase.
  2. **El viaje de una celda** — las 7 etapas animadas en secuencia, para que se entienda el proceso
     de un vistazo (es el corazón de la app y hoy no se ve en ningún sitio junto).
  3. **Identificar y medir** — la etiqueta de una línea, el OCR y el test masivo.
  4. **Entregar y proteger** — informes PDF, etiquetas y respaldo.
- **Se puede saltar** en cualquier momento (botón «Saltar» visible desde la primera pantalla).
- **No bloquea nunca**: solo aparece en el primer arranque, y se puede **volver a ver desde Ajustes**.
- **Termina en la acción, no en un «listo»**: el último botón es **«Registrar mi primera celda»** y
  lleva directo al formulario. Un onboarding que termina en un vacío desperdicia todo lo que enseñó.
- Se guarda en preferencias (`onboarding_visto`), así que sobrevive a reinicios.
- **Aceptación:** instalación limpia → aparece el onboarding → saltar y completar funcionan → al
  completarlo abre el alta de celda → al reabrir la app no vuelve a salir → desde Ajustes se repite.

### ⚡ G2 — Animaciones de energía y carga · v0.12.0

**Por qué:** es el lenguaje visual de la app (baterías, litio, carga) y hoy no existe. Además
resuelve algo práctico: hoy el SoH es un número y un chip de color.

- **🔋 Batería que se llena** (el sello visual de CeldaPro): el icono de la celda se rellena hasta su
  nivel de SoH, con animación al aparecer. De un vistazo, sin leer: llena = buena, a la mitad = floja.
  Se colorea por veredicto (A/B/C/rechazo).
- **Barra de SoH animada**: crece hasta su valor al abrir la ficha, y la cifra **cuenta** hasta el
  número final. Informa de magnitud, no solo de número.
- **Línea de energía en el flujo**: las 7 etapas con un trazo que recorre las completadas. Hoy las
  etapas son una fila de etiquetas sin relación visual.
- **Pulso de escaneo**: la línea que barre mientras la cámara busca. Comunica «estoy trabajando».
- **Contadores del resumen**: los números del dashboard cuentan hasta su valor al abrir.
- **Ondas de carga en el estado vacío**: cuando no hay nada, una animación suave de batería
  cargando en vez de un icono gris muerto.
- **Aceptación:** con «reducir animaciones» activo, todo aparece directamente en su valor final, sin
  animar, y ninguna pantalla se ve rota.

### ✨ G3 — Micro-interacciones en toda la app · v0.13.0

**Por qué:** es lo que separa una app que funciona de una que se siente sólida. Y en un taller tienen
una función concreta: confirmar sin mirar.

- **Vibración con intención** (lo más importante de esta fase para el taller):
  - toque corto al cambiar de etapa o de veredicto,
  - doble pulso al guardar una medición o una celda,
  - vibración de aviso al intentar algo que no se puede (guardar sin datos).
  Con guantes y el teléfono en la mano, esto es más útil que cualquier animación.
- **Confirmación visual al guardar**: la fila/etiqueta afectada se resalta y vuelve a su sitio.
- **Esqueletos en vez de ruedas**: al cargar el inventario, bloques grises con brillo en el sitio
  donde van a ir las celdas, en lugar de un `CircularProgressIndicator` centrado. La pantalla no
  «salta» al llegar los datos.
- **Transición de foto (Hero)**: al abrir la ficha de una celda desde la foto, la imagen crece hasta
  su sitio en vez de aparecer de golpe.
- **Cambio de sección animado**: al pasar entre las 4 pestañas, el contenido entra con un
  desplazamiento corto (180 ms), no con un corte seco.
- **Botón de escaneo con estado**: late despacio, y al detectar un código da un pulso de confirmación.
- **Aceptación:** cada acción del usuario produce una respuesta perceptible; ninguna animación supera
  los 300 ms.

### 🧭 G4 — El flujo del usuario · v0.14.0

**Por qué:** es lo que Steve pidió como «mejora del flujo», y es donde más se gana en el día a día.

- **Arranque inteligente**: una instalación nueva abre en **Inventario** con el onboarding al frente;
  un taller con datos abre en **Resumen**. Hoy abre siempre en Resumen.
- **Estados vacíos que llevan a la acción**: los 5 estados vacíos dicen **qué hacer y con un botón que
  lo hace** («Registra tu primera celda» → abre el formulario). Hoy son un icono y un texto.
- **Barra de progreso del taller**: en Resumen, cuántas celdas están pendientes de medir y cuántas
  sin etiquetar, con acceso directo a resolverlo.
- **Atajo del paso siguiente**: en la ficha de una celda, un botón que ofrece **la acción que toca**
  según su etapa (recién llegada → «Medir»; clasificada → «Balancear»; balanceada → «Empacar»). Hoy
  hay que saberse el proceso para elegir del menú.
- **Confirmación de lote terminado**: al medir la última celda pendiente de un lote, un aviso claro
  con el resumen y el acceso al informe.
- **Aceptación:** desde una instalación nueva se puede llegar a tener una celda medida en menos de
  60 segundos sin haber usado la app antes.

---

## 4. Cómo lo entrego

| Versión | Contenido |
|---|---|
| **v0.11.0** | G1 onboarding animado + repetible desde Ajustes |
| **v0.12.0** | G2 animaciones de energía y carga |
| **v0.13.0** | G3 micro-interacciones y vibración |
| **v0.14.0** | G4 flujo del usuario |

En cada una: `flutter analyze` 0 issues, suite verde (con pruebas nuevas de lo añadido), APK firmado
con el keystore real, release publicada y `TODO.md` actualizado.

---

## 5. Opciones

### Opción A — Las cuatro fases en orden ⭐ *recomendada*

- **Ventajas:** el onboarding (lo que más falta) llega primero y solo. Cada fase se puede probar en el
  teléfono antes de la siguiente. Si las animaciones no te cuadran, se corrigen antes de construir
  encima. El orden va de más valor a más refinamiento.
- **Desventajas:** cuatro tandas de trabajo; las micro-interacciones llegan al final.

### Opción B — Onboarding + flujo primero (G1 + G4), animaciones después

- **Ventajas:** lo que cambia *cómo se usa* la app llega antes que lo que cambia *cómo se siente*.
- **Desventajas:** el onboarding queda «seco» (sin las animaciones que le dan vida) y habría que
  volver a tocarlo en la fase siguiente. Retrabajo.

### Opción C — Solo animaciones (G2 + G3)

- **Ventajas:** es lo más llamativo y se ve en seguida.
- **Desventajas:** ⚠️ **la menos recomendable.** Pule el acabado de una app que sigue sin explicarle
  nada a quien la abre por primera vez. Sería barniz sobre el hueco más grande.

**Mi recomendación: A.** El onboarding es lo que más falta y lo que más cambia la experiencia de un
taller nuevo. Las animaciones encima de eso se disfrutan; sin eso, son adornos.

---

## 6. Riesgos y límites honestos

- **No tengo teléfono ni celdas.** Verifico por pruebas automáticas, análisis y compilación. Las
  animaciones, en concreto, **no las puedo ver**: mido que el estado final sea correcto y que las
  pruebas pasen, pero si el *ritmo* se siente mal, eso solo se juzga con el teléfono en la mano. Te
  pediré que me digas si algo va lento o exagerado.
- **Riesgo de degradar la app.** Cada animación es trabajo en el hilo de dibujo. Es una app de taller
  con móviles modestos y ya lleva el OCR cargando el APK (42 MB). Por eso: duraciones cortas, sin
  animaciones costosas en listas largas, y **una prueba de que el inventario con 5 000 celdas sigue
  ágil** después de añadirlas. Si algo no se puede permitir, lo digo y lo dejo fuera.
- **No voy a añadir Lottie ni vídeos.** Son bonitos y pesan; el APK ya va cargado. Todo con lo que
  trae Flutter.
- **El onboarding no es una solución mágica.** Enseña el flujo, no arregla un flujo confuso. Por eso
  G4 (rediseñar el recorrido) va en el mismo plan y no después.
- **Nada de esto toca la capa de datos ni el formato de los ficheros.** Es interfaz: los respaldos,
  las etiquetas y los informes siguen siendo compatibles.
- **Sigue sin poder subirse el CI** (PAT sin scope `workflow`). Las releases las firmo a mano.
- **No toco la identidad visual** (verde litio, ámbar, Inter): las animaciones usan la paleta que ya
  existe.

---

## 7. Decisiones que necesito de Steve

1. **¿Qué opción?** A (recomendada), B o C.
2. **¿El onboarding debe poder saltarse**, o prefieres que obligue a verlo entero la primera vez?
   Yo recomiendo que se pueda saltar: obligar a alguien con prisa a ver cuatro pantallas molesta.
3. **¿El arranque en Inventario cuando no hay datos te parece bien**, o prefieres seguir abriendo
   siempre en Resumen?
