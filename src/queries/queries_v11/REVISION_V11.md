# Revisión adversaria V11 — hallazgos (4 lentes)

Verificación estática con 4 revisores independientes (sintaxis, cardinalidad, LOMLOE, universo/leakage).

## Estado de los archivos

| Archivo | Estado | Acción |
|---------|--------|--------|
| Q01a (EEN, todos los años) | ✅ corregido `MAX(bit)` → corre | Ejecutar |
| Q02 (target) | ✅ corregido `MAX(bit)` → corre | Ejecutar (reductor pendiente, ver abajo) |
| Q01b (EON, 2025) | ⛔ EN ESPERA | Resolver Primaria antes de ejecutar |

## Blockers confirmados

### B1 — Q01b mezcla evaluación inicial de Primaria con trimestre de Bach (CONFIRMADO con QDIAG_04c)
En 2025 hay DOS períodos `Tipo='E', Numero=1, Estado='A'`:
- `...B2D44E12DE08`: **08-sep → 07-dic** (~90 días) = 1er trimestre real → **Bachillerato**
- `...5ECF4E12DE08`: **12-sep → 18-sep** (6 días) = evaluación **inicial** → **Primaria**

El filtro `Tipo='E',Numero=1` NO distingue. Q01b reconstruiría para Primaria la nota
de la evaluación inicial, no del trimestre. → **Decisión pendiente** (ver QDIAG_06).

### B2 — El universo puede excluir alumnos LOMLOE 2025 (a verificar con QDIAG_05)
El gate `alumnos_validos` exige 1EV en EvaExpedienteNota. Pero el 1EV de 2025 vive en EON.
Un alumno 2025 sin fila 1EV en EEN quedaría fuera del universo, anulando el propósito de Q01b.
QDIAG_02 sugiere que casi todos tienen ≥1 fila EEN (52 vs 50), pero hay que medir el hueco
exacto (`alumnos_SIN_EON` en QDIAG_05). → Fix probable: gate `EXISTS(EEN 1EV) OR EXISTS(EON 1EV)`.

## Findings major (no bloquean ejecución, sí afectan resultados)

| # | Archivo | Problema | Fix propuesto |
|---|---------|----------|---------------|
| M1 | Q02 | `MAX(IsAprobado)` es reductor **optimista**: si en la final coexisten una nota aprobada y una suspensa, marca aprobado → infla `buen_alumno`. Dirección que arruina un modelo de riesgo. | Selección determinista por expediente con `ROW_NUMBER()` priorizando `Tipo='F'` sobre `'E'`, mayor `Numero`. |
| M2 | Q01a + Q02 | `LEFT JOIN EvaCalificacion` por `(Codigo, GuidTablaCalificaciones)` puede no ser único → fan-out que infla `n_raw_rows` y contamina el reductor. | `OUTER APPLY (SELECT TOP 1 ...)` en vez de LEFT JOIN. Verificar unicidad con diagnóstico. |
| M3 | Q01b | `AVG(NotaValor)` simple ignora `EvaObjetivo_Evaluacion.Peso` (confirmado int en QDIAG_04b, valores 0.2). La nota LOMLOE real es media **ponderada**. | `SUM(NotaValor*Peso)/NULLIF(SUM(Peso),0)`. |
| M4 | Q01b | `eon.NotaValor IS NOT NULL` descarta criterios sin calificar en silencio → sesga la media; sin control de cobertura mínima. | Añadir `COUNT` criterios totales vs no-NULL; umbral mínimo de cobertura. |
| M5 | Q01b | `TipoObjetivo=7` puede no cubrir toda la Primaria 2025 (podría haber 6=CE o 2/5). | Diagnóstico: ofertas por TipoObjetivo × nivel en 2025. |

## Findings menores / confirmaciones
- Anti-leakage de VALORES correcto: features solo usan `Tipo='E',Numero=1`; el target usa la final; el JOIN a la final en `alumnos_validos` es filtro de cohorte, no inyecta valores.
- Population = alumnos-año con 1EV + evaluación final (survivorship). Documentar en metodología.
- Guard `ob.GuidOferta = e.GuidOferta` en Q01b: correcto e intencional, mantener.
- `o.Ejercicio = av.Ejercicio` no se reata en las queries externas: inocuo SI una matrícula = un ejercicio. Añadir guard defensivo o verificar.
- Escala `NotaValor` 0-10: confirmada para muestra TipoObjetivo=7; verificar que no haya escalas mixtas (rúbricas 0-4).

## Diagnósticos a correr antes de cerrar V11
1. **QDIAG_05** — cobertura 2025 EEN vs EON (mide B2).
2. **QDIAG_06** — calendario de evaluaciones 2025 por nivel (resuelve B1: ¿tiene Primaria un trimestre real en EON?).
