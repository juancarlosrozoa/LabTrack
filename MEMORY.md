# MEMORY.md — LabTrack

Memoria del proyecto entre sesiones. Máximo ~50 líneas: resume o elimina lo que ya no aporte.

## Estado actual

- Flujo completo funcional y verificado en dispositivo real: registro → confirmación de email → crear/unirse a lab → invitar con roles → gating de permisos por rol en la UI.
- Backend sin bugs conocidos pendientes (los 3 encontrados el 2026-07-12/13 están corregidos, ver migraciones 012-014).
- Manual de usuario (ES/EN/FR) actualizado y descargable como PDF desde la app (Settings → Help) y desde `docs/`.
- Distribución a clientes internos: por ahora vía APK de release enviado directamente (no Firebase App Distribution, por costo/complejidad mientras el proyecto es chico).

## Decisiones (y por qué)

- Gating de permisos se implementa ocultando/deshabilitando botones en UI según `LabRole`, además de la RLS — la RLS sola deja al usuario ver el botón y fallar con un error crudo.
- `ProductsScreen` se eliminó en vez de conectarla — Inventory ya cubre listar/buscar productos, era una pantalla duplicada que nunca se usó.
- Manual de usuario: PDFs generados con `npx md-to-pdf` y commiteados en `docs/` (no generación en runtime) — más simple que integrar una librería de PDF en Flutter.

## Aprendizajes y errores a evitar

- Ver sección "Reglas de dominio / trampas conocidas" en `CLAUDE.md` — ahí van las trampas de Postgres/Supabase, no repetir aquí.
- El emulador Android de este entorno es inutilizable para pruebas interactivas; usar siempre el dispositivo físico del usuario por USB.

## Próximos pasos

- Integración con otras apps del ecosistema de laboratorio del usuario — sin definir aún (APIs, datos compartidos, auth unificada).
- Revisar si hay más funciones `SECURITY DEFINER` sin `search_path` fijado, o más `upsert(onConflict: ...)` sobre columnas nullable, antes de asumir que el resto del backend está sano.
