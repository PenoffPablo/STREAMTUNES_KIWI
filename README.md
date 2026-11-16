<div align="center">
  <img src="assets/images/logo.png" alt="StreamTunes Logo" width="160" />
  <h1>StreamTunes</h1>
  <p><strong>Plataforma nativa de streaming musical y autogestión para la escena independiente</strong></p>
</div>

StreamTunes es una plataforma nativa de streaming musical y gestión comunitaria diseñada específicamente para bandas independientes, colectivos underground y escenas autogestionadas. La aplicación combina reproducción de audio de alta fidelidad, sincronización de letras, analítica agregada para artistas, integración con pasarelas de pago y capacidades de sincronización resiliente ante entornos sin conectividad (offline-first).

---

## Tabla de Contenidos

- [Vision General](#vision-general)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
- [Funcionalidades Principales](#funcionalidades-principales)
  - [Reproductor y Experiencia Auditiva](#reproductor-y-experiencia-auditiva)
  - [Sistema de Roles y Navegacion Adaptativa](#sistema-de-roles-y-navegacion-adaptativa)
  - [Panel de Control para Musicos (Dashboard)](#panel-de-control-para-musicos-dashboard)
  - [Aportes y Pasarela de Pago (Mercado Pago)](#aportes-y-pasarela-de-pago-mercado-pago)
  - [Notificaciones Push (Firebase Cloud Messaging)](#notificaciones-push-firebase-cloud-messaging)
  - [Resiliencia Offline y Escaneo QR Inteligente](#resiliencia-offline-y-escaneo-qr-inteligente)
  - [Ingesta y Validacion Criptografica de Audio](#ingesta-y-validacion-criptografica-de-audio)
  - [Biblioteca y Listas de Reproduccion](#biblioteca-y-listas-de-reproduccion)
- [Pila Tecnologica](#pila-tecnologica)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Esquema de Base de Datos y Seguridad](#esquema-de-base-de-datos-y-seguridad)
- [Instalacion y Configuracion](#instalacion-y-configuracion)
  - [Requisitos Previos](#requisitos-previos)
  - [Configuracion del Entorno](#configuracion-del-entorno)
  - [Configuracion de Firebase (push)](#configuracion-de-firebase-push)
  - [Ejecucion en Desarrollo](#ejecucion-en-desarrollo)
  - [Ejecucion de Pruebas](#ejecucion-de-pruebas)
  - [Compilacion de Paquetes de Distribucion](#compilacion-de-paquetes-de-distribucion)
- [Licencia](#licencia)

---

## Vision General

El modelo tradicional de distribución digital a menudo excluye o precariza a los artistas independientes debido a intermediarios costosos, requerimientos de conectividad constante y métricas de consumo opacas. 

StreamTunes responde a esta problemática implementando:
1. **Conexión Directa:** Soporte financiero voluntario y directo a través de transferencias y preferencias dinámicas de Mercado Pago sin comisiones ocultas.
2. **Resiliencia en Recitales:** Mecanismo offline para captura y suscripción a bandas en recitales subterráneos o espacios cerrados con señal deficiente, sincronizándose de manera automática al recuperar red.
3. **Gestión Integral:** Herramientas para que cada agrupación administre su discografía, conciertos, galerías y estadísticas con cuotas controladas para mitigar la saturación de infraestructura.

---

## Arquitectura del Sistema

La app sigue **MVVM en capas**, con la estructura recomendada por la guía oficial de arquitectura de Flutter. Las dependencias van en **un solo sentido**:

```text
 UI  ──────────────────────────▶  DATA  ──────────────────▶  DOMAIN
 View  ──▶  ViewModel             Repository  ──▶  Service    Models (inmutables)
 (widgets)  (ChangeNotifier)      (interfaz + Fake/Supabase)
                 ▲
                 └── creados por la raíz de composición (config/dependencies.dart)
```

* **View (`ui/<feature>/views`)**: solo dibuja el estado del ViewModel y le delega las acciones. **No importa nada de `data/`**: no toca repositorios, servicios, `url_launcher` ni `MethodChannel`.
* **ViewModel (`ui/<feature>/view_models`)**: estado y lógica de presentación. Todos heredan de `ViewModel` (`ui/core/view_model.dart`), que evita el error *"ChangeNotifier used after being disposed"* cuando un `await` termina después de que se cerró la pantalla.
* **Repository (`data/repositories/<x>/`)**: una interfaz (`x_repository.dart`) y dos implementaciones en archivos separados: `x_repository_supabase.dart` (producción) y `x_repository_fake.dart` (offline y tests).
* **Service (`data/services/`)**: acceso a plataforma (audio, cámara, deep links, notificaciones, isolates). Son **clases inyectables**, no métodos `static`.
* **Domain (`domain/models/`)**: modelos inmutables, sin dependencias de Flutter.
* **Raíz de composición (`config/dependencies.dart`)**: el **único** lugar que conoce las implementaciones concretas. Elige Fake o Supabase y expone fábricas `createXxxViewModel()`. Las Views obtienen sus ViewModels a través de `DependenciesScope`.

### Ciclo de vida
* Cada View crea su ViewModel en `initState` y lo libera en `dispose`. `didChangeDependencies` se usa **solo** cuando el ViewModel depende de un dato heredado que puede cambiar (por ejemplo, la banda activa en `BandDashboardView`).
* Los ViewModels no tienen efectos en el constructor: se arrancan con `init()`.
* Los `TextEditingController` de los diálogos pertenecen a widgets con estado (`TextInputDialog`, `AddEventDialog`, `EditSongDialog`) y se liberan en `dispose`.
* `context` nunca se usa después de un `await` sin chequear `mounted`. `Navigator` y `ScaffoldMessenger` se capturan antes del `await`.
* Ciclo de vida de la app: `AppLifecycleListener` sincroniza los follows offline al volver a primer plano, y `didHaveMemoryPressure` libera la caché de imágenes.
* Los recursos de larga vida (worker isolate, canal realtime, reproductor, streams) se liberan en `AppDependencies.dispose()`.

### Concurrencia: Future, Stream e Isolates
| Concepto | Dónde |
|---|---|
| `(f1, f2).wait` tipado con *records* | carga de feed, biblioteca, perfil de banda, panel y moderación |
| `timeout` + excepción de dominio | `withNetworkTimeout()` en todas las consultas a Supabase |
| "Última petición gana" | `HomeViewModel.loadFeed` descarta respuestas viejas |
| Reintentos con backoff (`Future.delayed`) | `retry()` en la sincronización offline |
| `Future.wait` en paralelo con fallos parciales | `PendingFollowService.sync` |
| `Completer` | inicialización única de notificaciones y push; handshake del worker isolate |
| `FutureBuilder` | letra de la canción en `NowPlayingModal` |
| `StreamTransformer` propio (`debounce`) | búsqueda mientras se escribe |
| `map` / `where` / `distinct` / `asyncMap` | deep links, auth, donaciones en vivo, push |
| `StreamBuilder` | progreso de reproducción (sin reconstruir toda la app en cada tick) |
| `async*` / `yield` | `AudioAnalyzerService.analyzeWithProgress` |
| `StreamController` con `onListen`/`onCancel` | canal realtime de donaciones (se abre y cierra según los oyentes) |
| Isolate de larga vida con `SendPort`/`ReceivePort` | análisis de audio con progreso y **cancelación** |
| `Isolate.run` | reporte CSV firmado del panel de banda |
| `compute` | parseo de letras LRC |
| Isolate en segundo plano | `Workmanager` y el handler de push en background |

## Funcionalidades Principales

### Reproductor y Experiencia Auditiva
* Reproducción continua de audio en primer plano y segundo plano utilizando servicios nativos del sistema operativo.
* Visualización gráfica de formas de onda (waveform) calculadas a partir de la densidad acústica del archivo.
* Letras sincronizadas en formato LRC con desplazamiento temporal automático según la posición del cursor de audio.
* Notificaciones interactivas de reproducción con controles multimedia en la bandeja del sistema.

### Sistema de Roles y Navegacion Adaptativa
El menú inferior y las secciones disponibles se adaptan estrictamente al contexto de autenticación y privilegios del usuario:
* **Visitante Anónimo:** Acceso a exploración, reproducción y cuenta (2 pestañas).
* **Oyente Registrado:** Acceso a exploración, biblioteca personal y gestión de perfil (3 pestañas).
* **Músico con Banda Activa:** Incorpora módulos de publicación/subida de audio y panel de control de banda (5 pestañas).
* **Administrador / Moderador:** Panel de control de contenido con capacidad de revisión, aprobación y resolución de reportes de moderación.

### Panel de Control para Musicos (Dashboard)
* **Métricas Diarias de Servidor:** Visualización de reproducciones totales, minutos globales acumulados y desempeño de los últimos 7 días mediante funciones almacenadas en PostgreSQL (`RPC`).
* **Ranking de Audiencia (Top 10 Fans):** Desglose ordenado de los usuarios con mayor tiempo de escucha, respetando configuraciones de privacidad (anonimización automática para oyentes con perfiles restringidos).
* **Control de Saturación:** Límite estricto de una consulta pesada directa al servidor por día, con almacenamiento en caché local (`SharedPreferences`) para consultas recurrentes.
* **Agenda de Conciertos:** Alta, baja y consulta de fechas de presentaciones en vivo con enlace a boleterías.
* **Galería Fotográfica:** Mantenimiento visual de registros fotográficos de eventos pasados.

### Aportes y Pasarela de Pago (Mercado Pago)
* La preferencia de pago se crea en la Edge Function `mercadopago-create-preference`. El **Access Token vive solo en el servidor** (secret), nunca en la app.
* Cada intento de donación tiene un id (uuid) generado por la app, que viaja a Mercado Pago. El webhook lo usa como clave de la fila (`ON CONFLICT DO NOTHING`): ni los reintentos de Mercado Pago ni el botón "Ya transferí" generan duplicados.
* El donante se toma de la sesión (JWT), nunca del cliente. Sin sesión, la donación queda sin donante.
* Si la banda no cargó un alias propio, solo se ofrece el checkout: no hay alias por defecto.
* Desglose transparente de la comisión estimada frente al monto neto para el artista.
* Donaciones en tiempo real en el perfil público mediante Supabase Realtime.
* Si la pasarela no está disponible, se copia el alias y se abre la app de Mercado Pago.

### Notificaciones Push (Firebase Cloud Messaging)
* La app registra el token FCM del dispositivo en `device_tokens` al iniciar sesión, lo actualiza cuando rota y lo borra al cerrar sesión.
* La Edge Function `send-push` (disparada por Database Webhooks) envía:
  * **Nuevo tema** a los seguidores de la banda (INSERT en `songs`).
  * **Aporte recibido** a los miembros de la banda (INSERT en `donations`).
* Push con la app abierta: se muestra como notificación local. Push con la app en segundo plano o cerrada: lo muestra el sistema operativo.
* Al tocar la notificación se abre el perfil de la banda.

### Resiliencia Offline y Escaneo QR Inteligente
* Generación de códigos QR únicos por banda aptos para impresión física o proyección en recintos.
* Lector de códigos con cámara integrada (`mobile_scanner`) y alternativa de entrada manual para emuladores y entornos de escritorio.
* Detección de conectividad: si el fan escanea dentro de un recinto subterráneo sin cobertura celular, la solicitud se encola en `PendingFollowService`.
* Sincronización transparente en segundo plano tan pronto el dispositivo restablece la conexión a Internet al reanudar la aplicación (`AppLifecycleState.resumed`).

### Ingesta y Validacion Criptografica de Audio
* Validación de cabeceras binarias para formatos legítimos de audio digital (MP3 / ID3, WAV / RIFF, AAC / M4A).
* Cálculo de firma criptográfica SHA-256 para evitar duplicidad o plagio dentro de la plataforma.
* Extracción algorítmica de 40 muestras de picos de amplitud para modelar la forma de onda visual antes de la publicación.
* Cuotas de catálogo reguladas: restricción a un máximo de 20 temas y 2 álbumes por banda para preservar la sustentabilidad del colectivo.

### Biblioteca y Listas de Reproduccion
* Creación, edición y ordenamiento posicional de listas de reproducción personalizadas.
* Incorporación y remoción de canciones en listas de reproducción en tiempo real.
* Seguimiento de agrupaciones favoritas con actualización reactiva y soporte para refresco manual (*pull-to-refresh*).

---

## Pila Tecnologica

* **Lenguaje:** Dart 3.13+
* **Framework:** Flutter 3.47+ (soporte nativo Android y Desktop)
* **Backend:** Supabase Cloud / PostgreSQL 15+
* **Autenticacion:** Supabase Auth (Email / Password, Sesiones JWT)
* **Almacenamiento Binario:** Supabase Storage (Buckets dedicados: `audio` y `covers`)
* **Base de Datos en Tiempo Real:** PostgreSQL CDC (Change Data Capture) vía WebSockets
* **Reproduccion:** `just_audio`, `audio_service`, `audio_session`
* **Escaneo y Graficos QR:** `mobile_scanner`, `qr_flutter`
* **Persistencia Local:** `shared_preferences`
* **Notificaciones Push:** Firebase Cloud Messaging (`firebase_core`, `firebase_messaging`) + `flutter_local_notifications`

---

## Estructura del Proyecto

```text
lib/
├── main.dart                     # Arranque: plataforma, modo dual y raíz de la app
├── config/
│   ├── environment.dart          # Variables --dart-define
│   └── dependencies.dart         # Raíz de composición + fábricas de ViewModels
├── domain/
│   └── models/                   # Modelos inmutables (Song, Band, Donation, ...)
├── data/
│   ├── repositories/
│   │   └── <x>/                  # x_repository.dart (interfaz)
│   │                             # x_repository_supabase.dart / x_repository_fake.dart
│   └── services/
│       ├── audio/                # Reproductor, analizador (worker isolate), LRC
│       ├── device/               # Cámara/archivos, deep links, lanzador externo
│       ├── notifications/        # Notificaciones locales, Workmanager, push (FCM)
│       ├── reports/              # Reporte CSV firmado (Isolate.run)
│       └── storage/              # Cola offline de follows
├── ui/
│   ├── core/                     # ViewModel base, scopes, tema, widgets compartidos
│   └── <feature>/                # account, admin, band_dashboard, band_public, home,
│       ├── view_models/          # library, navigation, player, session, upload
│       └── views/
└── utils/                        # Timeouts, reintentos, errores, transformadores de Stream
supabase/
├── functions/                    # mercadopago-create-preference, mercadopago-webhook, send-push
└── migrations/                   # device_tokens (push), integridad de donaciones
```

## Esquema de Base de Datos y Seguridad

El backend opera sobre PostgreSQL con políticas estrictas de seguridad a nivel de fila (**Row Level Security - RLS**):

* `bands`: Información institucional, enlaces, géneros y estado de moderación.
* `songs`: Catálogo musical, rutas binarias de almacenamiento, firmas SHA-256 y picos de onda.
* `playlists`: Agrupaciones creadas por los usuarios con soporte de ordenamiento numérico.
* `playlist_songs`: Tabla relacional que vincula temas y listas manteniendo la posición secuencial.
* `band_follows`: Relación muchos a muchos entre usuarios y bandas seguidas.
* `donations`: Registro contable de transferencias, estados de aprobación y mensajes públicos/privados.
* `device_tokens`: Tokens FCM por dispositivo (cada usuario solo ve los suyos).
* `app_admins`: Lista de control de acceso para miembros con facultades de moderación sobre el colectivo.
* `band_events` y `band_photos`: Fechas de conciertos y galerías de presentaciones.

---

## Instalacion y Configuracion

### Requisitos Previos
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.47.0 o superior)
* [Dart SDK](https://dart.dev/get-dart) (versión 3.13.0 o superior)
* [Android Studio](https://developer.android.com/studio) y Android SDK (API 34 recomendada) para despliegues móviles
* Git

### Configuracion del Entorno
Clone el repositorio en su espacio de trabajo local:

```bash
git clone https://github.com/PenoffPablo/STREAMTUNES_KIWI.git
cd STREAMTUNES_KIWI
```

Instale las dependencias del proyecto:

```bash
flutter pub get
```

### Configuracion de Firebase (push)
1. Cree un proyecto en la [consola de Firebase](https://console.firebase.google.com) y agregue la app Android `com.streamtunes.app.streamtunes`.
2. Instale la CLI y configure el proyecto. Esto genera `google-services.json` y agrega el plugin de Gradle:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. Aplique la migración `supabase/migrations/20261116000000_device_tokens.sql`.
4. Despliegue la función y cargue los secretos:
   ```bash
   supabase functions deploy send-push --no-verify-jwt
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)" PUSH_WEBHOOK_SECRET=<valor-secreto>
   ```
5. En Supabase, vaya a **Database → Webhooks** y cree dos webhooks (INSERT en `songs` e INSERT en `donations`) que hagan POST a la función `send-push` con el header `x-webhook-secret: <valor-secreto>`.

Sin `google-services.json` la app funciona igual: el push queda desactivado y se registra un aviso en el log.

### Base de datos
`supabase/schema.sql` es una instantánea de la base real. Encima se aplican, en orden, las migraciones de `supabase/migrations/`:

```bash
supabase db push
```

La migración `20261116010000_donations_integrity.sql` hace dos cosas: el total de cada banda pasa a contar solo donaciones aprobadas, y se elimina la política que permitía a cualquier usuario editar o borrar donaciones.

La migración `20261116020000_rls_hardening.sql` cierra las políticas abiertas (`using (true)`) de `songs`, `playlists`, `playlist_songs`, `band_photos`, `band_follows` y Storage. Cada operación queda limitada a quien corresponde: miembros de la banda, dueño de la playlist, el propio usuario o moderadores.

### Secretos de Mercado Pago
```bash
supabase functions deploy mercadopago-create-preference --no-verify-jwt
supabase functions deploy mercadopago-webhook --no-verify-jwt
supabase secrets set MP_ACCESS_TOKEN=APP_USR-...
```

Las dos funciones van con `--no-verify-jwt`:
* **`mercadopago-webhook`** la llama Mercado Pago, que no tiene sesión de Supabase.
* **`mercadopago-create-preference`** la llaman también fans sin cuenta, y las claves `sb_publishable_` no son JWT. La función identifica al donante por su cuenta, a partir del token de sesión si existe.

### Ejecucion en Desarrollo
Para iniciar la aplicación en un emulador o dispositivo físico conectado:

```bash
flutter run
```

### Ejecucion de Pruebas
El proyecto cuenta con una suite completa de pruebas unitarias y de integración que validan el cumplimiento de las reglas de negocio, adaptabilidad de interfaz y cálculos en hilos aislados:

```bash
flutter test
```

### Compilacion de Paquetes de Distribucion

Para compilar el binario optimizado para Android (Release APK):

```bash
flutter build apk --release
```

El archivo resultante se generará en la ruta:
`build/app/outputs/flutter-apk/app-release.apk`

Para compilar para plataformas de escritorio (Windows):

```bash
flutter build windows --release
```

---

## Licencia

Distribuido bajo la Licencia MIT. Consulte el archivo `LICENSE` para obtener más información.
