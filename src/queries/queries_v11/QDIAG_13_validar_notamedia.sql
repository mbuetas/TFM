-- ============================================================================
-- QDIAG_13 — Validar EvaExpedienteNotaMedia como fuente UNIVERSAL de notas
-- ============================================================================
-- NotaMedia aparece en TODOS los años (2020-2025) con 1EV y final, y es una
-- media por (alumno, asignatura, evaluación). Si su columna Valor es numérica
-- 0-10 y la cobertura es buena, podría ser la fuente única cross-year que evita
-- tener que mezclar EEN/EON/AspectoNota por año. Pero Valor es varchar → validar.
-- ============================================================================

-- ── PARTE A: ¿qué contiene Valor? Top 40 valores más frecuentes ─────────────
SELECT TOP 40
    em.Valor,
    COUNT(*) AS n
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaExpediente e ON e.Guid = em.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio >= 2020
GROUP BY em.Valor
ORDER BY n DESC;

-- ── PARTE B: ¿qué fracción de Valor es numérica? por año (SQL2008: ISNUMERIC) ─
-- TRY_CONVERT no existe en SQL Server 2008. ISNUMERIC=1 marca valores numéricos.
-- El min/max numérico se mira en la Parte A (Top 40 valores) para evitar
-- CONVERT sobre textos no numéricos.
SELECT
    o.Ejercicio,
    COUNT(*)                                                  AS n_filas,
    SUM(CASE WHEN ISNUMERIC(em.Valor) = 1 THEN 1 ELSE 0 END)  AS n_numericas
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaExpediente e ON e.Guid = em.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio >= 2020
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;

-- ── PARTE C: calendario de NotaMedia — cobertura por (año, Tipo, Numero) ─────
-- Muestra para qué períodos hay media, con alumnos y asignaturas (filtros de
-- matrícula aplicados, como en producción). Buscamos años con 1EV (E/1) y final
-- (E/F con Numero alto) bien cubiertos en asignaturas.
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado,
    COUNT(DISTINCT m.GuidAlumno)        AS n_alumnos,
    COUNT(DISTINCT e.GuidOferta)        AS n_asignaturas,
    COUNT(*)                            AS n_notas
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaEvaluacion ev ON ev.Guid = em.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = em.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;
