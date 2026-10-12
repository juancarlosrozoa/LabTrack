---
name: labtrack-pitfalls
description: Úsala siempre que escribas o revises migraciones de Supabase (funciones SECURITY DEFINER, triggers, upsert con onConflict, selects embebidos de PostgREST) o pantallas de LabTrack con botones que escriben datos (agregar/editar/eliminar, registrar movimientos, iniciar conteos, gestionar miembros).
---

# Trampas conocidas de LabTrack

Tres bugs reales de producción (2026-07-12/13) salieron todos de la misma familia: asunciones razonables sobre Postgres/PostgREST que resultaron falsas. Antes de escribir o revisar código en estas áreas, revisa esta lista.

## Reglas — backend (Supabase/Postgres)

- Toda función `SECURITY DEFINER` que haga referencia a tablas sin calificar (`insert into profiles`, no `insert into public.profiles`) debe declarar `set search_path = public` explícitamente. Sin esto, si el trigger se dispara desde un contexto distinto (ej. un INSERT en `auth.users` iniciado por GoTrue), Postgres no encuentra la tabla y falla con `relation "x" does not exist` — silencioso hasta que revisas los Postgres Logs del dashboard.
- Un `.select('tabla_b(col1, col2)')` embebido de PostgREST **requiere una FK directa entre las dos tablas involucradas**. No basta con que ambas referencien una tercera tabla en común (ej. las dos apuntan a `auth.users.id`) — eso no es suficiente para que PostgREST infiera el join. Si agregas una tabla nueva que se relaciona con otra vía un embed, agrega la FK explícita en la misma migración.
- `upsert(data, onConflict: 'col_a,col_b')` solo detecta el conflicto si ninguna columna del target puede ser `NULL` en la fila — Postgres trata `NULL <> NULL` dentro de un unique constraint normal, así que el "conflicto" nunca se detecta y cada llamada inserta una fila nueva en silencio. Si una de las columnas del conflict target es nullable (común en patrones "config general vs. config por item", donde `item_id is null` significa "la config general"), la constraint debe ser `unique nulls not distinct (col_a, col_b)`.
- Antes de asumir que un bug de "Something went wrong" genérico es un problema de RLS/permisos, confirma el HTTP status real en los Postgres/Auth Logs del dashboard de Supabase — un 200 con error del lado del cliente (ej. `.maybeSingle()` lanzando porque hay más de una fila) es indistinguible en la UI de un verdadero fallo de backend, pero la causa y el fix son completamente distintos.

## Reglas — UI (gating de permisos por rol)

- RLS en el backend no oculta botones en la UI. Toda pantalla con una acción de escritura (agregar/editar producto, registrar movimiento, iniciar conteo, gestionar miembros, etc.) debe leer `currentLabRoleProvider` y condicionar el widget con `role?.canWrite` o `role?.canManage` — si no, un usuario sin permiso ve el botón, lo toca, llena el formulario, y recién al enviar choca con un error crudo de Postgres en vez de nunca ver la opción.
- `canWrite` = cualquier rol excepto `viewer`. `canManage` = `admin` o `manager`. Verifica en `supabase/migrations/002_rls.sql` qué rol mínimo exige la política RLS de la tabla que estás tocando, y usa el gate de UI equivalente — deben coincidir.

## Checklist de revisión

- [ ] ¿Esta función/trigger es `SECURITY DEFINER` y referencia tablas sin `public.` ni `search_path` fijado?
- [ ] ¿Este `.select()` embebe una tabla relacionada? Si sí, ¿existe la FK directa entre ambas?
- [ ] ¿Este `upsert` tiene un `onConflict` con alguna columna nullable? Si sí, ¿la constraint es `nulls not distinct`?
- [ ] ¿Este botón/acción escribe datos? Si sí, ¿está condicionado por `canWrite`/`canManage` y coincide con la política RLS real?

## Al terminar

Indica qué puntos del checklist comprobaste y cómo (ej. "revisé la migración X, la constraint ya usa nulls not distinct").
