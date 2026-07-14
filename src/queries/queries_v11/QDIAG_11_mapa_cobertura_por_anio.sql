-- ============================================================================
-- QDIAG_11 — Mapa de cobertura de notas por AÑO y por TABLA (2020+)
-- ============================================================================
-- Hipótesis: 2021-2024 se excluyeron porque sus notas, bajo LOMLOE, no están en
-- EvaExpedienteNota (boletín) sino en EvaObjetivoNota (criterios) o
-- EvaAspectoNota (competencias). El filtro original solo miraba EEN.
--
-- Este mapa cuenta, por año y por fuente, cuántos alumnos y asignaturas tienen
-- nota de 1EV y de evaluación final. Un año es RECUPERABLE si en alguna fuente
-- tiene buena cobertura de 1EV (asignaturas ≈ las que cursa el alumno) Y de final.
--
-- 1EV   = EvaEvaluacion Tipo='E', Numero=1
-- final = EvaEvaluacion Tipo IN ('E','F'), Numero>=3
-- (sin filtro de Estado para no perder datos en la exploración)
-- ============================================================================

-- ── RESULTADO 1: denominador — alumnos y asignaturas matriculados por año ────
SELECT
    o.Ejercicio,
    COUNT(DISTINCT m.GuidAlumno)        AS alumnos_matriculados,
    COUNT(DISTINCT o.Guid)              AS ofertas_evaluables,
    COUNT(DISTINCT e.Guid)              AS expedientes
FROM dbo.EvaExpediente  e
JOIN dbo.EvaOferta      o   ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula      m   ON m.Guid = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;

-- ── RESULTADO 2: cobertura 1EV y final por (año, fuente) ────────────────────
-- EEN — EvaExpedienteNota (boletín)
SELECT o.Ejercicio, 'EEN' AS fuente,
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN m.GuidAlumno END) AS alumnos_1ev,
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN e.GuidOferta END) AS asig_1ev,
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN m.GuidAlumno END) AS alumnos_final,
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN e.GuidOferta END) AS asig_final
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente  e   ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio

UNION ALL
-- EON — EvaObjetivoNota (criterios LOMLOE)
SELECT o.Ejercicio, 'EON',
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN e.GuidOferta END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN e.GuidOferta END)
FROM dbo.EvaObjetivoNota eon
JOIN dbo.EvaObjetivo_Evaluacion oev ON oev.Guid = eon.GuidObjetivo_Evaluacion
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = oev.GuidEvaluacion
JOIN dbo.EvaExpediente  e   ON e.Guid  = eon.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio

UNION ALL
-- ASP — EvaAspectoNota (competencias clave)
SELECT o.Ejercicio, 'AspectoNota',
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN e.GuidOferta END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN e.GuidOferta END)
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = an.GuidEvaluacion
JOIN dbo.EvaExpediente  e   ON e.Guid  = an.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio

UNION ALL
-- ENM — EvaExpedienteNotaMedia (media calculada por asignatura)
SELECT o.Ejercicio, 'NotaMedia',
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo='E' AND ev.Numero=1                     THEN e.GuidOferta END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN m.GuidAlumno END),
    COUNT(DISTINCT CASE WHEN ev.Tipo IN ('E','F') AND ev.Numero>=3           THEN e.GuidOferta END)
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = em.GuidEvaluacion
JOIN dbo.EvaExpediente  e   ON e.Guid  = em.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2020
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio

ORDER BY Ejercicio, fuente;
