# Ganadería La Victoria — Manual Ganadero (app Flutter)

> Documento de contexto generado por análisis exhaustivo del código (nov. 2026).
> Objetivo: que cualquier persona o IA que entre a este repo entienda el proyecto completo
> sin tener que releer todo el código desde cero. Actualízalo cuando el proyecto cambie
> de forma importante (nuevas pantallas, cambios de arquitectura, nuevas integraciones).

## 1. Qué es este proyecto

**Nombre interno:** `manual_ganadero_flutter` · **Nombre comercial:** "Manual Ganadero" / "Ganadería La Victoria"
**applicationId Android:** `com.lavictoria.ganaderia` · **Proyecto Firebase:** `soyganadero-10eb5`

App móvil (Flutter, Android + iOS) para que ganaderos mexicanos administren su rancho desde el
celular: registro de animales, salud, reproducción, finanzas, inventario, calendario de eventos,
estadísticas del hato, y un asistente de inteligencia artificial (chat + comandos de voz) para
consultas veterinarias/genéticas/nutricionales y para registrar datos hablando en lugar de
tecleando. Incluye un marketplace para comprar/vender ganado entre usuarios de la app.

Pensada para operar **sin conexión constante**: usa persistencia offline ilimitada de Firestore,
por lo que el rancho sigue funcionando sin señal y sincroniza al reconectar.

## 2. Estado funcional actual

**Compila limpio y sin avisos.** `flutter analyze` da `No issues found!` (0 de 0 — se limpiaron los
~185 avisos de estilo/lint que había en el análisis original de nov. 2026: imports sin usar,
`BuildContext` cruzando `async gaps`, APIs deprecadas como `Share.shareXFiles`, `value:` en lugar de
`initialValue:`, `Radio`/`groupValue` migrado a `RadioGroup`, etc. — ver sección 2.1). Build
verificado con `flutter build web --debug` y `flutter build apk --debug`. Hay tests unitarios reales
en `test/` (`models_test.dart`, `quota_service_test.dart`) que corren con `flutter test`.

**Lo que SÍ funciona de punta a punta (código completo, conectado a Firestore):**
- Autenticación (email/password + Google Sign-In), onboarding de rancho, aceptación de términos.
- Multi-rancho por usuario (un usuario puede tener varios ranchos y cambiar entre ellos).
- CRUD completo de animales (alta manual, edición, detalle con gráfica de peso, import masivo
  desde Excel).
- Módulos de negocio: Leche, Genética (simulador de cruzas), Engorda, Reproductora, Sanidad
  (medicamentos y días de retiro), Reportes (PDF).
- Finanzas (ingresos/egresos), Inventario de insumos, Calendario con notificaciones locales
  programadas, Estadísticas del hato (fl_chart).
- Chat de IA con Gemini (`gemini-2.5-flash`) con RAG manual sobre los datos reales del rancho
  (animales, vacunas, preñez, eventos), 4 modos (veterinario/genética/nutrición/general), soporta
  texto + imagen + documentos adjuntos.
- Asistente de voz ("habla y la app registra"): transcribe con `speech_to_text`, interpreta la
  intención con Gemini (`AIVoiceService`), confirma y ejecuta la acción (alta/edición/baja de
  animal, registrar peso/vacuna/evento) directo en Firestore.
- Sistema de cuotas/paywall para el chat de IA (`QuotaService`): 5 consultas gratis/mes, paquetes
  pagados (10/25 consultas, vigencia 12 meses) y suscripción premium mensual, vendidos vía
  `in_app_purchase`.
- Marketplace de compra/venta de animales entre usuarios (colección global, no por rancho).

**Lo que NO está terminado / no funciona aún:**
- **IAP (compras in-app) no verificado en producción.** El código de `DonationsScreen` /
  `QuotaService` está completo, pero depende de configuración manual en Play Console (IDs de
  producto: `consults_pack_10`, `consults_pack_25`, `premium_monthly`) que debe existir y estar
  activa del lado de la tienda — no es algo que se pueda probar completo en debug/local.
- **Dos placeholders sin reemplazar** en [lib/core/app_constants.dart](lib/core/app_constants.dart):
  número de WhatsApp de soporte (`521XXXXXXXXXX`) y URL de App Store (`idXXXXXXXXX`). Bloqueantes
  antes de publicar en iOS o de que el botón de soporte funcione de verdad. Se dejaron así a
  propósito (decisión del usuario, nov. 2026) hasta tener los datos reales.
- **`GEMINI_API_KEY` sigue viajando en el cliente** (ver sección 6) — se decidió explícitamente
  posponer la migración a un backend/Cloud Function porque implica activar Firebase Blaze y es un
  proyecto aparte, no un simple fix.

### 2.1 Limpieza de riesgos/errores realizada (nov. 2026)

En una segunda ronda se corrigió todo lo señalado arriba que era seguro de arreglar sin tocar
comportamiento visible ni de negocio:
- Se eliminó el **modelo TFLite huérfano** (`tflite_flutter`, `image`, `assets/models/`) — no tenía
  ninguna pantalla que lo usara, decisión del usuario fue quitarlo en vez de implementarlo.
- Se eliminó **`lib/services/firebase_service.dart`** (código muerto confirmado).
- Se reemplazó **`test/widget_test.dart`** (boilerplate roto) por `test/models_test.dart` y
  `test/quota_service_test.dart` con cobertura real de la lógica más frágil (round-trip de
  `Animal.fromFirestore/toFirestore`, y toda la lógica de cuotas/premium de `QuotaService`).
- Se corrigieron los ~185 avisos de `flutter analyze` hasta dejarlo en `No issues found!`, incluyendo
  los `use_build_context_synchronously` reales (riesgo de crash si el widget se desmonta durante un
  `await`) y la migración de `RadioListTile.groupValue/onChanged` a `RadioGroup` en el formulario de
  transacciones — verificado contra el código fuente del SDK de Flutter instalado para confirmar que
  cada reemplazo (`value:`→`initialValue:`, `activeColor:`→`activeThumbColor:`, `desiredAccuracy:`→
  `locationSettings:`, parámetros sueltos de `speech_to_text`→`SpeechListenOptions`) es 100%
  equivalente en comportamiento, sin cambios visuales ni funcionales.
- Verificado con `flutter analyze` (0 issues), `flutter test` (19/19 tests), `flutter build web
  --debug` y `flutter build apk --debug` (ambos compilan sin errores).

## 3. Arquitectura técnica

- **Flutter** puro, sin gestor de estado (no hay Provider/Bloc/Riverpod). Cada pantalla es un
  `StatefulWidget` que llama directo a Firestore con `StreamBuilder`/`FutureBuilder`.
- **Backend = Firebase**: Auth, Firestore (con persistencia offline ilimitada), Storage, Google
  Sign-In. No hay servidor propio ni Cloud Functions detectadas — toda la lógica vive en el cliente.
- **IA = Google Gemini vía HTTP REST directo** (paquete `http`, no SDK), con `GEMINI_API_KEY` en
  `.env` (cargado con `flutter_dotenv`). No hay backend intermedio: el cliente llama a la API de
  Gemini directamente, lo que significa que **la API key viaja empaquetada en el binario de la
  app** (riesgo a tener en cuenta — ver sección de mejoras).
- **Sin capa de repositorio consistente**: existe `FirestoreService` con helpers para construir
  referencias (`users/{uid}/ranches/{ranchId}/...`), pero la mayoría de pantallas instancian
  `FirebaseFirestore.instance` directamente en vez de pasar por ese servicio.

### Estructura de carpetas (`lib/`)

```
lib/
├── main.dart                 → entry point, rutas nombradas, AuthCheck/_UserRouter
├── firebase_options.dart     → generado por FlutterFire CLI
├── core/app_constants.dart   → constantes globales (soporte, legal, store links)
├── models/                   → Animal, AnimalStat, CalendarEvent, MarketplaceListing, Product, Transaction
├── services/                 → AuthService, FirestoreService, QuotaService, AIVoiceService,
│                                NotificationService, ModuleService
├── widgets/                  → dashboard_widgets, dashboard_charts, live_voice_dialog, voice_action_dialog
└── screens/
    ├── principal/            → Login, Register, Dashboard (hub), Tutorial onboarding
    ├── bovino/               → listado/alta/edición/detalle de animales, import Excel
    ├── calendar/             → calendario de eventos + notificaciones locales
    ├── estadisticas/         → dashboard analítico del hato
    ├── finance/              → ingresos/egresos
    ├── inventario/           → insumos y suministros
    ├── intelligence/         → chat IA (Gemini + RAG propio)
    ├── marketplace/          → compra-venta de ganado entre usuarios
    ├── modulos/              → Leche, Genética, Engorda, Reproductora, Sanidad, Reportes
    ├── noticias/              → noticias globales + notificaciones in-app
    └── profile/              → perfil, ranchos, ajustes, legal, compras, borrar cuenta
```

## 4. Modelo de datos en Firestore

```
users/{uid}
  ├─ setupCompleted, termsAccepted, tutorialSeen, currentRanchId, name
  ├─ quota { monthKey, monthlyUsed, isPremium, premiumExpiry, paidBatches[...] }
  ├─ ranches/{ranchId}
  │    ├─ name, location, hectares, lat/lng
  │    ├─ animals/{animalId}        → ver Animal model
  │    ├─ calendarEvents/{eventId}
  │    ├─ products/{productId}      → inventario
  │    ├─ transactions/{transId}    → finanzas
  │    └─ slaughter_records/{id}    → solo desde engorda_screen
  ├─ purchases/{transactionId}      → historial de compras IAP
  └─ inAppNotifications/{id}

marketplace_listings/{listingId}    → colección GLOBAL (no anidada por usuario)
global_news/{id}                    → colección GLOBAL de noticias
```

Puntos importantes para no romper nada al tocar datos:
- **Todo lo del rancho vive anidado bajo `users/{uid}/ranches/{ranchId}/...`** — si agregas una
  colección nueva de negocio, debe ir ahí, no en la raíz.
- El **marketplace y las noticias son las únicas colecciones globales** — cualquier dato que deba
  verse entre usuarios distintos va ahí, con su propio control de ownership (`ownerId`).
- Los modelos (`Animal`, `Product`, `Transaction`, etc.) usan `fromFirestore(Map, id)` /
  `toFirestore()` tolerantes a nulls y a `Timestamp` vs `String` en fechas — sigue ese patrón si
  agregas campos nuevos.

## 5. Flujo de uso de la app (de principio a fin)

1. **Arranque** (`main.dart` → `AuthCheck`): si no hay sesión → `LoginScreen`. Si la sesión tiene
   más de 7 días, se fuerza cierre de sesión por seguridad.
2. **Primer login** (`_UserRouter`): si `users/{uid}.setupCompleted != true` → `RanchSetupScreen`
   (crea el primer rancho, pide ubicación con `geolocator`). Si `termsAccepted != true` →
   `TermsAcceptanceScreen` (gate obligatorio). Si todo OK → `DashboardScreen`.
3. **Dashboard** (hub central, sin bottom nav ni drawer): selector de rancho activo, tarjetas de
   acceso a cada módulo. Los módulos **Leche / Genética / Engorda / Reproductora** se
   desbloquean dinámicamente según el campo `purpose` que tengan los animales ya registrados
   (stream en tiempo real sobre `animals`) — por eso el primer paso real del ganadero siempre es
   **registrar al menos un animal**.
4. **Registro de animales** — dos caminos:
   - Manual: `BovinoScreen` → FAB → `RegisterAnimalScreen` (foto, arete/pierna, raza, sexo,
     propósito, genealogía, preñez, vacunas).
   - Por voz: botón de micrófono → `LiveVoiceDialog`/`VoiceActionDialog` → transcribe → Gemini
     interpreta intención (`AIVoiceService`) → muestra resumen de confirmación → al confirmar,
     escribe directo en Firestore.
   - Masivo: `ImportAnimalsScreen` con plantilla `.xlsx` de 18 columnas.
5. **Operación diaria**: calendario de eventos (partos, vacunas, revisiones) con notificaciones
   locales programadas; registro de pesos/vacunas desde el detalle del animal o por voz; módulos
   especializados según el propósito del hato; finanzas e inventario en paralelo.
6. **Consulta de IA**: desde `IntelligenceScreen`, elige modo (veterinario/genética/nutrición/
   general), opcionalmente selecciona un "animal en foco" o adjunta foto/documento; el RAG propio
   junta contexto real del rancho antes de preguntar a Gemini. Cada consulta exitosa descuenta
   cuota (`QuotaService.consumeConsult()`), con paywall si se acaba.
7. **Marketplace** (opcional): el ganadero elige un animal propio (`SelectAnimalToPublishScreen`),
   lo publica en `marketplace_listings` (colección global, visible a todos los usuarios, filtrable
   por estado de México).
8. **Reportes**: desde `ReportesScreen`, exporta PDF de inventario de animales o finanzas y lo
   comparte/imprime.

### Reglas de negocio no obvias a tener en mente
- Un animal sin `purpose` no desbloquea ningún módulo especializado — vale la pena que el
  formulario de alta deje claro que ese campo no es "opcional" en la práctica.
- El asistente de voz tiene valores por defecto fuertes si el usuario no especifica algo (sexo →
  "Hembra", propósito → "Reproductora", raza → "Otro") — revisar `ai_voice_service.dart` antes de
  cambiar esos defaults porque están documentados ahí mismo con ejemplos.
- La cuota premium no es realmente "ilimitada": tiene un tope invisible de 1500 consultas/mes
  (`QuotaService.kPremiumMonthlyLimit`) para evitar abuso; esto es intencional, no un bug.

## 6. Mejoras sugeridas pendientes (de mayor a menor impacto)

> Los puntos de código ya corregidos (TFLite huérfano, `firebase_service.dart` muerto, tests,
> avisos de `flutter analyze`) se movieron a la sección 2.1. Lo que queda abajo son decisiones que
> requieren input del usuario (dinero, cuentas externas, datos reales) y por eso no se tocaron.

1. **Sacar la `GEMINI_API_KEY` del cliente**. Hoy viaja embebida en el binario (vía `.env`
   empaquetado como asset) y es extraíble por cualquiera que descompile el APK. Lo correcto a
   mediano plazo es mover las llamadas a Gemini detrás de una Cloud Function o un backend propio
   que valide al usuario y oculte la key. Pospuesto a propósito: requiere activar Firebase Blaze
   y es un proyecto de arquitectura aparte, no un fix rápido.
2. **Completar los placeholders de `app_constants.dart`** (WhatsApp real, URL de App Store) antes
   de cualquier publicación — hoy el botón de soporte y el enlace de iOS no llevan a nada real.
   Pendiente de que el usuario tenga esos datos.
3. **Unificar el acceso a datos detrás de `FirestoreService`** en vez de que cada pantalla
   instancie `FirebaseFirestore.instance` directo — facilita testear y cambiar la estructura de
   colecciones sin tocar 20 archivos.
4. **Validar el flujo de IAP contra Play Console real** (los product IDs existen en el código pero
   no se puede confirmar que estén activos/aprobados en la tienda sin revisar la consola).

## 7. Notas para trabajar en este repo (humano o IA)

- El código y los comentarios están en **español** — mantener ese idioma en comentarios/strings
  nuevos para consistencia.
- No hay gestor de estado: si agregas una pantalla nueva, sigue el patrón existente
  (`StatefulWidget` + `StreamBuilder`/`FutureBuilder` sobre Firestore), no introduzcas Provider/Bloc
  a menos que se decida migrar todo el proyecto a la vez.
- Antes de asumir que una dependencia de `pubspec.yaml` está en uso, **verifica con grep** — en
  nov. 2026 se encontró `tflite_flutter`/`image` declaradas sin ningún código consumidor (ya se
  eliminaron, ver sección 2.1), lo que confirma que el `pubspec.yaml` no siempre refleja el código
  real.
- Las rutas nombradas en `main.dart` casi nunca reciben argumentos vía `ModalRoute` (excepción:
  `/marketplaceProductDetail`); el resto de la navegación con parámetros usa
  `Navigator.push(MaterialPageRoute(builder: ...))` pasando el ID por constructor.
- Este archivo (`CLAUDE.md`) debe actualizarse cuando cambie algo estructural importante
  (nueva integración, nueva colección de Firestore, cambio de arquitectura) para que siga siendo
  confiable como punto de partida.
