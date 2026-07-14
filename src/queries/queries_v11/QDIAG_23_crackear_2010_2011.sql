-- ============================================================================
-- QDIAG_23 — ¿Por qué 2010/2011 desaparecen? (los años con más datos)
-- ============================================================================
-- Con IsMatriculaPrincipal=1 + NoMatriculado=0, 2010 da 0 y 2011 ~20 alumnos,
-- pero tienen 37k/34k notas. Algún filtro los mata. Identificamos cuál y vemos
-- si son recuperables con un pipeline aparte.
-- ============================================================================

-- ── PARTE A: notas de 2010/2011 por valor de IsMatriculaPrincipal ───────────
-- ¿Las matrículas de esos años están marcadas como principales?
SELECT
    o.Ejercicio,
    m.IsMatriculaPrincipal,
    COUNT(DISTINCT m.GuidAlumno)  AS n_alumnos,
    COUNT(DISTINCT e.Guid)        AS n_expedientes,
    COUNT(*)                      AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaExpediente e ON e.Guid = en.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2010, 2011)
JOIN dbo.Matricula     m ON m.Guid = e.GuidMatricula
GROUP BY o.Ejercicio, m.IsMatriculaPrincipal
ORDER BY o.Ejercicio, m.IsMatriculaPrincipal;

-- ── PARTE B: notas de 2010/2011 por NoMatriculado ───────────────────────────
SELECT
    o.Ejercicio,
    e.NoMatriculado,
    COUNT(DISTINCT m.GuidAlumno)  AS n_alumnos,
    COUNT(*)                      AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaExpediente e ON e.Guid = en.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2010, 2011)
JOIN dbo.Matricula     m ON m.Guid = e.GuidMatricula
GROUP BY o.Ejercicio, e.NoMatriculado
ORDER BY o.Ejercicio, e.NoMatriculado;

-- ── PARTE C: estructura de períodos 2010/2011 SIN filtros de matrícula ──────
-- ¿Tienen un 1EV (E/1) y un final reales una vez quitados los filtros?
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado,
    COUNT(DISTINCT m.GuidAlumno)  AS n_alumnos,
    COUNT(*)                      AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaEvaluacion ev ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.Ejercicio IN (2010, 2011)
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;
