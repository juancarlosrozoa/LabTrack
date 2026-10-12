---
description: Planifica una nueva funcionalidad antes de tocar código
argument-hint: <descripción de la funcionalidad>
disable-model-invocation: true
---
Quiero añadir esta funcionalidad a LabTrack: $ARGUMENTS

Antes de escribir código, prepárame un plan con:
1. Cómo la vas a implementar, respetando las reglas de CLAUDE.md (especialmente la sección "Reglas de dominio / trampas conocidas" y el gating de permisos por rol si la funcionalidad toca escritura de datos).
2. Qué archivos vas a modificar o crear, y qué cambia en cada uno (incluye migraciones de Supabase si aplica — recuerda que el usuario debe correrlas él mismo en el SQL Editor).
3. Los casos límite y las dudas que debo decidir yo antes de empezar.
4. Qué actualizarías en CLAUDE.md y en MEMORY.md al terminar.

Ten en cuenta el estado actual del proyecto: @MEMORY.md

No modifiques ningún archivo hasta que apruebe el plan.
