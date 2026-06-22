# App Móvil — Control Almacén (Flutter)

Cliente móvil del sistema **Control Almacén** de ENCOSSA. Permite al personal de campo
(encargados, capataces, liquidadores y encargados de almacén) gestionar pedidos,
devoluciones, inventarios, consumos, liquidaciones y saldos de camión desde el celular.

Consume la API REST del backend Django (carpeta `../Control_almacen/`,
ver `../Control_almacen/README.md`).

---

## 1. Stack tecnológico

- **Flutter** (Dart SDK `^3.11.5`), Material 3.
- **HTTP**: `http` para consumir la API REST.
- **Estado**: `provider` (`AuthProvider`).
- **Almacenamiento seguro**: `flutter_secure_storage` (tokens JWT).
- **Preferencias**: `shared_preferences`.
- **Notificaciones push**: `firebase_core` + `firebase_messaging` +
  `flutter_local_notifications`.
- **Otros**: `intl` (fechas/formatos), `flutter_svg`, `share_plus`, `path_provider`.
- **Icono de app**: `flutter_launcher_icons` (`assets/icon/cora_icon.png`).

---

## 2. Estructura del proyecto

```
app_movil/
├── lib/
│   ├── main.dart                     # Entry point: Firebase, tokens, splash/router
│   ├── core/
│   │   ├── api_service.dart          # Cliente HTTP singleton + manejo de JWT/refresh
│   │   ├── auth_provider.dart        # Estado de sesión (login, autologin, logout)
│   │   ├── constants.dart            # kBaseUrl + IDs de Rol
│   │   ├── notification_service.dart # Inicialización FCM / notificaciones locales
│   │   └── assets_paleta.dart        # Paleta para la pantalla de dibujo
│   ├── models/
│   │   ├── usuario.dart   pedido.dart   devolucion.dart
│   │   ├── inventario.dart   sst.dart   elemento_canvas.dart
│   └── screens/
│       ├── login_screen.dart
│       ├── home_screen.dart          # Menú principal (opciones según rol)
│       ├── saldos/                   # Saldos de camión
│       ├── pedidos/                  # Crear / listar / aprobar pedidos
│       ├── devoluciones/             # Crear / listar / aprobar devoluciones
│       ├── inventarios/              # Crear / listar inventarios
│       ├── liquidacion/             # Liquidación de suministros por SST/semana
│       ├── planos/                   # Lista de SST por fecha → plano de cada SST
│       └── dibujo/                   # Lienzo de dibujo (croquis del plano)
├── assets/
│   ├── icon/                         # Icono de la app
│   └── svg/
├── android/  ios/  web/  windows/  macos/  linux/
└── pubspec.yaml
```

---

## 3. Configuración de la API

En `lib/core/constants.dart`:

```dart
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://control-almacen-n56o.onrender.com/api/',
);
```

- Por defecto apunta al backend en **producción (Render)**.
- Para apuntar a un backend local, compila pasando `--dart-define`:

```bash
# Emulador Android (el host es 10.0.2.2)
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api/

# Simulador iOS / escritorio
flutter run --dart-define=BASE_URL=http://localhost:8000/api/
```

---

## 4. Autenticación y sesión

- `AuthProvider` (en `core/auth_provider.dart`) gestiona el login y el `tryAutoLogin()`
  que se ejecuta en el splash (`main.dart` → `_SplashRouter`).
- `ApiService` guarda `token` y `refresh_token` en `flutter_secure_storage`.
- Cada petición autenticada agrega el header `Authorization: Bearer <token>`.
- Cuando el `access` expira (HTTP 401), `ApiService._tryRefresh()` renueva el token
  automáticamente usando el `refresh_token` y reintenta la petición.

Flujo de arranque:

```
main() → Firebase.initializeApp()
       → ApiService().loadToken()
       → NotificationService().init()
       → _SplashRouter → tryAutoLogin()
            ├─ ok    → HomeScreen
            └─ falla → LoginScreen
```

---

## 5. Navegación por rol

`home_screen.dart` arma el menú dinámicamente según las capacidades del usuario
(`usuario.puedeHacerPedido`, `puedeAprobarPedido`, `puedeLiquidar`, etc.):

| Opción | Visible para | Pantalla |
|--------|--------------|----------|
| Mis Saldos | quien ve saldos propios | `SaldosScreen(soloMios: true)` |
| Saldos Camiones | quien ve todos los saldos | `SaldosScreen(soloMios: false)` |
| Pedidos | Encargado / Capataz | `PedidosScreen` |
| Devoluciones | Encargado / Capataz | `DevolucionesScreen` |
| Pedidos por Despachar | Encargado Almacén | `AprobacionPedidosScreen` (con badge) |
| Devoluciones por Aprobar | Encargado Almacén | `AprobacionDevolucionesScreen` (con badge) |
| Liquidación | Liquidador | `LiquidacionScreen` |
| Inventarios | Encargado Almacén | `InventariosScreen` |
| Planos | quien puede dibujar (hoy: Encargado) | `PlanosSstScreen` → `DibujoScreen(sstCodigo)` |

Los IDs de rol se definen en `constants.dart`:

```dart
class Rol {
  static const int superadmin       = 1;
  static const int adminEmpresa     = 2;
  static const int encargado        = 3;
  static const int capataz          = 4;
  static const int liquidador       = 5;
  static const int encargadoAlmacen = 6;
}
```

Los aprobadores ven **contadores de pendientes** (badges) cargados desde
`ApiService().getPendientesConteo()`.

---

## 6. Funcionalidades principales

- **Saldos**: consulta de stock por camión.
- **Pedidos**: el Encargado/Capataz crea un pedido al almacén; el Encargado de Almacén lo
  aprueba o rechaza (ajustando cantidades).
- **Devoluciones**: flujo análogo al de pedidos.
- **Inventarios**: levantamiento de inventario de camión/almacén por mes.
- **Liquidación**: liquidación de suministros agrupados por SST y semana de trabajo
  (consume datos de actividad desde la API).
- **Planos por SST**: cada SST tiene **un plano editable** (croquis). Se entra por una lista
  de SST agrupada por fecha de programación (mismo patrón que Liquidación, datos de Render),
  con badge **Con plano / Sin plano**. Al tocar un SST se abre el lienzo con su plano.
- **Dibujo (lienzo)**: editor de croquis con paleta de elementos SVG (`screens/dibujo/`).
- **Notificaciones push**: avisos de pedidos/devoluciones vía Firebase Cloud Messaging.

### Planos por SST (detalle)

- **Acceso:** Home → **Planos** → `PlanosSstScreen` (lista de SST por fecha) → tocar un SST →
  `DibujoScreen(sstCodigo:)`.
- **Identidad:** el plano se asocia por **código de SST** (el que llega de Render), no por la
  tabla local — consistente con cómo Liquidación usa `sst_externo`. Un SST puede aparecer en
  varias fechas, pero abre siempre **el mismo** plano único.
- **Almacenamiento:** se guarda en el servidor como **JSON editable** (lista de
  `ElementoCanvas`: `assetId, x, y, escala, rotacion, z`), de modo que el plano se puede
  **reabrir y seguir editando**. El **PNG** se sigue generando **localmente** para compartir.
- **Endpoints consumidos** (`ApiService`):
  - `getSemanaPlanos(usuarioId)` → `GET /api/planos/semana_sst/?usuario=`
  - `getPlano(sstCodigo)` → `GET /api/planos/?sst_codigo=`
  - `guardarPlano(sstCodigo, usuarioId, elementos)` → `POST /api/planos/` (upsert)
- **Serialización:** `models/elemento_canvas.dart` (`toJson`/`fromJson`); al reconstruir, el
  `id` de cada elemento se regenera (no se persiste).

---

## 7. Instalación y ejecución

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Ejecutar (usa backend de producción por defecto)
flutter run

# 2b. O apuntando a un backend local
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api/

# 3. Generar icono de la app (si cambia assets/icon/cora_icon.png)
flutter pub run flutter_launcher_icons
```

### Compilar release

```bash
flutter build apk --release \
  --dart-define=BASE_URL=https://control-almacen-n56o.onrender.com/api/
```

---

## 8. Firebase / Notificaciones

- `main.dart` llama a `Firebase.initializeApp()` al arrancar.
- `NotificationService` inicializa FCM y las notificaciones locales.
- El token FCM del dispositivo se envía al backend y se guarda en `Usuario.fcm_token`,
  que es lo que el backend usa para enviar pushes (ver `core/fcm.py` en el backend).
- Requiere los archivos de configuración de Firebase por plataforma
  (`android/app/google-services.json`, etc.).

---

## 9. Notas

- La app es **multiplataforma** (Android, iOS, web, escritorio), pero el target principal es
  **Android** (`flutter_launcher_icons` solo genera icono Android).
- Toda la comunicación con el servidor pasa por el singleton `ApiService`; centralizar ahí
  cualquier endpoint nuevo.
- Los modelos en `lib/models/` reflejan los serializers del backend; al cambiar la API,
  actualizar ambos lados.
