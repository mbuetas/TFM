-- ============================================================================
-- QDIAG_21 — ¿Por qué 2010/2011 (los años más ricos) no entran al dataset?
-- ============================================================================
-- 2010=37k notas, 2011=34k notas, pero 0 alumnos pasan el gate (1EV E/1 +
-- final E/F Numero>=3, Estado='A', CodigoOficial no vacío). Algo de su
-- estructura difiere. Este diagnóstico mapea períodos y códigos de los años
-- nunca explorados (2010-2017).
-- ============================================================================

-- ── PARTE A: estructura de períodos por año (2010-2017), EEN ─────────────────
-- Revela qué Tipo/Numero/Estado usan estos años → cómo definir 1EV y final.
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado,
    COUNT(DISTINCT m.GuidAlumno)  AS n_alumnos,
    COUNT(DISTINCT e.GuidOferta)  AS n_ofertas,
    COUNT(*)                      AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaEvaluacion ev ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.Ejercicio BETWEEN 2010 AND 2017
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;

-- ── PARTE B: ¿las ofertas de 2010/2011 tienen CodigoOficial? ────────────────
-- Si están en blanco, el filtro de "asignatura real" también las bloquearía.
SELECT
    o.Ejercicio,
    COUNT(DISTINCT o.Guid)                                                          AS n_ofertas,
    COUNT(DISTINCT CASE WHEN o.CodigoOficial IS NOT NULL
                         AND LTRIM(RTRIM(o.CodigoOficial)) <> '' THEN o.Guid END)   AS n_con_codigo,
    COUNT(DISTINCT CASE WHEN o.IsEvaluable = 1 THEN o.Guid END)                     AS n_evaluables
FROM dbo.EvaOferta o
WHERE o.Ejercicio BETWEEN 2010 AND 2017
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;

-- ── PARTE C: muestra de nombres de asignatura de 2010/2011 ──────────────────
-- Para confirmar que son materias reales (y ver el formato de su código).
SELECT TOP 40
    o.Ejercicio, o.CodigoOficial, o.Nombre_Lng1,
    COUNT(*) AS n_ofertas
FROM dbo.EvaOferta o
WHERE o.Ejercicio IN (2010, 2011)
  AND o.IsEvaluable = 1
GROUP BY o.Ejercicio, o.CodigoOficial, o.Nombre_Lng1
ORDER BY o.Ejercicio, o.CodigoOficial;
