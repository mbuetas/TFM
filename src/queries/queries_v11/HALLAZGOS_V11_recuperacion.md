# Hallazgos V11 — Búsqueda exhaustiva de notas de 1er trimestre (2020-2025)

Investigación para recuperar años excluidos. Se buscó la nota de 1EV en **~10 tablas**
de notas del ERP, con la definición más inclusiva posible (cualquier período, ventana
por fecha sep–dic, jerarquía de fuente). Resumen del veredicto por año.

## Tablas revisadas
EvaExpedienteNota (boletín), EvaObjetivoNota (criterios LOMLOE), EvaAspectoNota
(competencias), EvaExpedienteNotaMedia (media calculada), EvaNotaDiariaNota (controles
de clase), EvaSubControlNota, EvaGradoDesarrolloNota, EvaExpedienteMediaCategoriaEstandares.

## Veredicto por año

| Año | Matriculados | Notas de 1EV disponibles | Veredicto |
|-----|--------------|--------------------------|-----------|
| 2018 | — | EEN denso (pre-LOMLOE) | ✅ usar |
| 2019 | — | EEN denso (pre-LOMLOE), mayor cohorte | ✅ usar |
| 2020 | 485 | EEN denso (200 al. 1EV / 141 final) + notas clase (12 asig) | ✅ usar (posible ampliar vs 109 actuales) |
| 2021 | 361 | EEN 29 al., final ~0; notas clase ~0 | ❌ features y target demasiado escasos |
| 2022 | 318 | 1EV ~1 asig útil, final 27 (solo NotaMedia) | ❌ insuficiente |
| 2023 | 362 | **0 notas en todas las tablas** | ❌ sin datos en el ERP |
| 2024 | 293 | **0 notas en todas las tablas** | ❌ sin datos en el ERP |
| 2025 | 308 | **solo "Lengua castellana"** (1 asig) en todas las tablas | ❌ una sola materia, no modelable |

## Causa raíz
LOMLOE entró de forma escalonada y este centro **dejó de cerrar el boletín de 1EV por
asignatura** en los años de transición. En 2025 solo el departamento de Lengua calificó
(por criterios/competencias); el resto de materias no tiene nota de 1er trimestre en ninguna
tabla. 2023/2024 no tienen ninguna nota cargada pese a tener matrículas.

## Decisión de dataset V11
- **Incluir**: 2012, 2016, 2018, 2019, 2020 (notas formales EEN, **deduplicadas** — fix del
  bug de duplicados que inflaba `n_suspensos`).
- **Excluir**: 2021, 2022 (escasos), 2023, 2024 (vacíos), 2025 (solo Lengua).
- Resultado: dataset más limpio y honesto que V8 (que incluía 2025 como ruido y sufría el
  bug de duplicación).

## Búsqueda exhaustiva de notas-letra (QDIAG_16) — CERRADA
Se verificó el vocabulario completo de notas en `EvaCalificacion` (tabla maestra:
código → `Valor` numérico + `IsAprobado`). Existe una escala cualitativa amplia
(SB, NT, BI, B, SU, S, IN, I, MB, RG/R, AP, NP, N+, N-, S+, S-, EX…). PERO:
- En `EvaExpedienteNota` el campo `NotaNumerico` YA está poblado aunque la nota sea
  una letra (B→6, N+→8, .6→6). Las notas-letra no estaban escondidas.
- Aun contando todas las letras, 2021/2022/2025 siguen con 1-2 asignaturas de 1EV
  por alumno (dominadas por 1 materia). 2023/2024 siguen vacíos.

Conclusión: búsqueda agotada en ~10 tablas × 3 formatos (número, texto CÓDIGO_NÚMERO,
letra pura). El dato de 1EV de 2021-2025 no existe en el ERP.

### Mejora aprovechable para los años buenos
`EvaCalificacion` es la tabla de conversión universal. La extracción de producción
debe resolver la nota vía JOIN a `EvaCalificacion` (código + GuidTablaCalificaciones →
`Valor` + `IsAprobado`), con `NotaNumerico` como respaldo, para captar también las notas
**cualitativas** de Primaria (SB/NT/BI/IN) sin perder materias.

## Para la memoria del TFM
La indisponibilidad de notas de 1EV bajo LOMLOE en el ERP es en sí un **hallazgo**: la
digitalización de la evaluación formativa por competencias/criterios es incompleta en el
centro, lo que limita la aplicabilidad de modelos de predicción temprana en el nuevo marco
legal. Es una limitación a declarar y, a la vez, una conclusión con valor.
