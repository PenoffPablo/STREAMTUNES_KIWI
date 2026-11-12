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
  - [Resiliencia Offline y Escaneo QR Inteligente](#resiliencia-offline-y-escaneo-qr-inteligente)
  - [Ingesta y Validacion Criptografica de Audio](#ingesta-y-validacion-criptografica-de-audio)
  - [Biblioteca y Listas de Reproduccion](#biblioteca-y-listas-de-reproduccion)
- [Pila Tecnologica](#pila-tecnologica)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Esquema de Base de Datos y Seguridad](#esquema-de-base-de-datos-y-seguridad)
- [Instalacion y Configuracion](#instalacion-y-configuracion)
  - [Requisitos Previos](#requisitos-previos)
  - [Configuracion del Entorno](#configuracion-del-entorno)
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

La solución adopta el patrón de diseño **MVVM (Model-View-ViewModel)** complementado con un esquema de repositorios abstractos y servicios desacoplados:

* **Presentación (Views):** Componentes basados en widgets reactivos y adaptativos que ajustan su disposición (móvil y escritorio) según las dimensiones de pantalla disponibles.
* **Lógica de Estado (ViewModels):** Implementada mediante primitivas nativas de Flutter (`ChangeNotifier`, `ListenableBuilder`, `InheritedNotifier`). No se emplean librerías externas de gestión de estado (como Bloc, Riverpod o Provider), maximizando el rendimiento y el control de ciclo de vida.
* **Capa de Abstracción de Datos (Repositories):** Interfaces formales (`SongsRepository`, `BandsRepository`, `PlaylistsRepository`, `DonationsRepository`, `AuthRepository`) con implementaciones duales:
  * Implementaciones concretas conectadas a PostgreSQL / Supabase Cloud.
  * Implementaciones en memoria deterministas utilizadas para pruebas unitarias herméticas y modo fuera de línea.
* **Cómputo Aislado (Isolates):** Procesamiento intensivo de archivos binarios (extracción de formas de onda, hashing criptográfico SHA-256 e inspección de cabeceras ID3) delegado a subprocesos dedicados (`Isolate.run`) para garantizar que el hilo principal de la interfaz mantenga 60 FPS estables.

---

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
* Integración oficial con la API de Mercado Pago Checkout Preferences.
* Generación dinámica de intenciones de pago con montos exactos y bloqueados (tanto predefinidos como personalizados sin límite superior).
* Desglose transparente en pantalla de comisiones estimadas de procesamiento bancario versus monto neto percibido por el artista.
* Notificaciones en tiempo real en el perfil público de la banda mediante suscripciones WebSocket de base de datos (`supabase_realtime`).
* Copia instantánea de alias bancario (`penoff.pablo`) en el portapapeles del dispositivo para transferencias directas.

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

---

## Estructura del Proyecto

```text
lib/
├── models/             # Modelos de dominio inmutables (Song, Band, Donation, AppUser, Album, etc.)
├── repositories/       # Abstracciones de datos y clientes de Supabase / Fakes
├── scopes/             # Inyeccion de dependencias e InheritedNotifiers (RepositoriesScope, SessionScope)
├── services/           # Logica utilitaria (AudioPlayerService, AudioAnalyzerService, MercadoPagoService, etc.)
├── theme/              # Paleta de colores, tipografias y estilos globales de diseño
├── view_models/        # Logica de negocio y estado reactivo para cada vista
├── views/              # Interfaces graficas y componentes adaptativos
├── widgets/            # Modales reutilizables, barras de navegacion y controles auxiliares
└── main.dart           # Punto de entrada de la aplicacion y orquestacion de arranque
```

---

## Esquema de Base de Datos y Seguridad

El backend opera sobre PostgreSQL con políticas estrictas de seguridad a nivel de fila (**Row Level Security - RLS**):

* `bands`: Información institucional, enlaces, géneros y estado de moderación.
* `songs`: Catálogo musical, rutas binarias de almacenamiento, firmas SHA-256 y picos de onda.
* `playlists`: Agrupaciones creadas por los usuarios con soporte de ordenamiento numérico.
* `playlist_songs`: Tabla relacional que vincula temas y listas manteniendo la posición secuencial.
* `band_follows`: Relación muchos a muchos entre usuarios y bandas seguidas.
* `donations`: Registro contable de transferencias, estados de aprobación y mensajes públicos/privados.
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
git clone https://github.com/usuario/streamtunes.git
cd streamtunes
```

Instale las dependencias del proyecto:

```bash
flutter pub get
```

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
