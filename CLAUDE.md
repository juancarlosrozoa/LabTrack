# LabTrack

App móvil Flutter de inventario de laboratorio (multi-tenant, offline-first) con Supabase como backend. Objetivo actual: dejarla lista para entrega a un cliente interno.

## Stack y estructura

- Flutter (Android/iOS únicamente — `firebase_options.dart` no tiene config para Windows/Web, no corre ahí).
- Estado: Riverpod. Navegación: go_router (`lib/shared/router/app_router.dart`). Local: Drift/SQLite (offline-first, sync a Supabase).
- Backend: Supabase (Postgres + Auth + RLS + Edge Functions). Migraciones numeradas en `supabase/migrations/*.sql`, aplicadas a mano vía el SQL Editor del dashboard (no hay CLI linkeado ni service key disponible).
- `lib/features/<feature>/{screens,providers,services}` — un feature por carpeta.
- `lib/data/{models,local,remote,repositories,sync}`, `lib/shared/{widgets,router,screens}`, `lib/core/{constants,errors,theme,utils}`.
- `docs/MANUAL_{ES,EN,FR}.{md,pdf}` — manual de usuario trilingüe, visible en la app (Settings → Help) y descargable.

## Comandos

- Analizar: `flutter analyze`
- Tests: `flutter test`
- Correr en dispositivo físico (ver Reglas de dominio): `source dart_define.sh && flutter run -d <device-id> --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY`
- Build release APK: mismo `--dart-define` con `flutter build apk --release`
- `dart_define.sh` (gitignored) tiene las credenciales de Supabase — si no existe, pedírselas al usuario (URL + anon/publishable key), nunca inventarlas.

## Convenciones

- Código y UI en inglés. Manual de usuario y conversación con el usuario en español.
- Commits sin línea "Co-Authored-By".
- Roles de lab: `admin > manager > analyst > viewer` (`lib/data/models/lab_membership.dart`). `canWrite` = no-viewer, `canManage` = admin/manager. Toda pantalla con botones de escritura debe ocultarlos/deshabilitarlos según el rol — la RLS del backend ya lo bloquea, pero sin el gate en UI el usuario ve el botón y choca con un error crudo de Postgres al enviar.

## Reglas de dominio / trampas conocidas

- **Funciones `SECURITY DEFINER` en Postgres necesitan `set search_path = public` explícito.** Sin esto, al dispararse desde un contexto distinto (ej. un trigger en `auth.users`) no resuelven nombres de tabla sin calificar y fallan con `relation "x" does not exist`. Pasó con `handle_new_user()` y bloqueaba el registro de cualquier usuario nuevo.
- **Los `.select('tabla_b(col1, col2)')` embebidos de PostgREST necesitan una FK real entre las dos tablas**, no solo una referencia común a una tercera. `lab_members.user_id` y `profiles.id` ambos referenciaban `auth.users.id` pero no entre sí — el embed fallaba con "Something went wrong" hasta agregar la FK directa.
- **`upsert(onConflict: 'col_a,col_b')` no funciona si alguna columna del conflict target puede ser `NULL`** — Postgres trata `NULL <> NULL` en unique constraints, así que nunca detecta el conflicto y cada "upsert" inserta una fila nueva. Fix: `unique nulls not distinct (col_a, col_b)`.
- El emulador Android en este entorno (sandboxed Windows) no tiene aceleración GPU real y es inutilizable (ANRs constantes) — usar siempre un dispositivo físico por USB (`adb devices`, autorizar depuración).
- `ProductsScreen` fue eliminada (código muerto, nada navegaba ahí) — los productos se gestionan desde Inventory y el detalle de producto, no desde un catálogo separado.

## Forma de trabajar

- Para cambios chicos y bugfixes puntuales, directo. Para features nuevas o cambios de esquema de datos, usar modo Plan o `/feature` antes de tocar código.
- Antes de dar un bug de backend por "misterioso", sospechar primero de las trampas conocidas de arriba — las tres encontradas hasta ahora salieron de ahí.
- Al terminar una tarea no trivial, actualizar `MEMORY.md`.

## Límites

- ✅ Siempre: correr `flutter analyze` después de cambios en `lib/`; confirmar antes de aplicar migraciones de Supabase (el usuario las corre él mismo en el SQL Editor, no hay acceso de servicio).
- ⚠️ Pregunta antes: agregar dependencias nuevas a `pubspec.yaml`, cambios de esquema de Supabase, acciones destructivas (`git push --force`, borrar datos).
- 🚫 Nunca: inventar URLs o credenciales de Supabase: si `dart_define.sh` no existe, pedirlas.

## Verificación

- `flutter analyze` y `flutter test` deben pasar limpios (hoy solo quedan 8 `info` preexistentes, no bloqueantes).
- Para cambios de UI, correr en el dispositivo físico conectado y verificar visualmente — no dar un cambio visual por bueno solo porque compila.

## Memoria

@MEMORY.md
- Al terminar una tarea, actualiza `MEMORY.md`: estado actual, decisiones importantes (con su porqué) y errores a evitar.
- Mantenlo breve (máximo ~50 líneas): resume o elimina lo que ya no aporte.
- No guardes nunca datos sensibles (claves, tokens).
