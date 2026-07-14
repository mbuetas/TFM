-- ============================================================================
-- QDIAG_16 — Vocabulario completo de notas (incluye letras/cualitativas)
-- ============================================================================
-- Objetivo: encontrar notas guardadas como LETRAS o códigos cualitativos
-- (SB/NT/BI/SU/IN, AP, A+, B-, diminutivos de Sobresaliente/Regular...) que
-- no estamos contando porque miramos columnas numéricas.
-- EvaCalificacion es la tabla MAESTRA: mapea cada código → valor + IsAprobado.
-- ============================================================================

-- ── PARTE A1: schema de EvaCalificacion (para ubicar la columna de valor) ────
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EvaCalificacion'
ORDER BY ORDINAL_POSITION;

-- ── PARTE A2: muestra completa — TODO el vocabulario de notas del sistema ────
SELECT TOP 120 *
FROM dbo.EvaCalificacion
ORDER BY Codigo;

-- ── PARTE A3: frecuencia de cada código (cuántas tablas de calificación) ─────
SELECT
    ec.Codigo,
    COUNT(*)                          AS n_apariciones,
    MIN(CAST(ec.IsAprobado AS INT))   AS apr_min,
    MAX(CAST(ec.IsAprobado AS INT))   AS apr_max
FROM dbo.EvaCalificacion ec
GROUP BY ec.Codigo
ORDER BY n_apariciones DESC;

-- ── PARTE B: ¿qué hay REALMENTE en NotaMedia para 2021/2022/2025? ───────────
-- Por (año, período): valores crudos distintos. Buscamos letras / blancos.
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero,
    em.Valor                          AS valor_crudo,
    COUNT(*)                          AS n
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaEvaluacion ev ON ev.Guid = em.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = em.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.Ejercicio IN (2021, 2022, 2025)
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, em.Valor
ORDER BY o.Ejercicio, ev.Numero, n DESC;

-- ── PARTE C: contenido real de EvaExpedienteNota (boletín) en 2021/2022 ─────
-- Códigos usados por período. Si hay un final (Numero alto) en letras, aparece.
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero,
    en.NotaCodigo,
    en.NotaNumerico,
    COUNT(*)                          AS n,
    COUNT(DISTINCT e.GuidMatricula)   AS n_alumnos
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaEvaluacion ev ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.Ejercicio IN (2021, 2022)
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, en.NotaCodigo, en.NotaNumerico
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero, n DESC;
