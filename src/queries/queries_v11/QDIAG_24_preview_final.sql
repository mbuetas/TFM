-- ============================================================================
-- QDIAG_24 — Preview del dataset FINAL (con todos los fixes) + código en 2010/11
-- ============================================================================
-- Fixes acumulados: NoMatriculado NULL-safe, Estado IN ('A','C'), filtro materia real.
-- Pregunta clave: ¿el filtro de CodigoOficial rompe 2010/2011 (materias con
-- código en blanco) o sus materias reales sí tienen código?
-- ============================================================================

-- ── PARTE A: ofertas de 2010/2011 CON código — ¿son materias reales? ────────
SELECT TOP 50
    o.Ejercicio, o.CodigoOficial, o.Nombre_Lng1, COUNT(*) AS n
FROM dbo.EvaOferta o
WHERE o.Ejercicio IN (2010, 2011)
  AND o.IsEvaluable = 1
  AND o.CodigoOficial IS NOT NULL AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
GROUP BY o.Ejercicio, o.CodigoOficial, o.Nombre_Lng1
ORDER BY o.Ejercicio, o.CodigoOficial;

-- ── PARTE B: cohorte por año bajo el gate FINAL, con vs sin filtro de código ─
WITH gate_con_codigo AS (
    SELECT DISTINCT m.GuidAlumno, o.Ejercicio
    FROM dbo.Matricula m
    JOIN dbo.EvaExpediente e ON e.GuidMatricula = m.Guid
         AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
    JOIN dbo.EvaOferta o ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1
         AND o.Ejercicio BETWEEN 2010 AND 2020
         AND o.CodigoOficial IS NOT NULL AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
    JOIN dbo.EvaExpedienteNota en1 ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion ev1 ON ev1.Guid = en1.GuidEvaluacion
         AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado IN ('A','C')
    JOIN dbo.EvaExpedienteNota enf ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion evf ON evf.Guid = enf.GuidEvaluacion
         AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado IN ('A','C')
    WHERE m.IsMatriculaPrincipal = 1
),
gate_sin_codigo AS (
    SELECT DISTINCT m.GuidAlumno, o.Ejercicio
    FROM dbo.Matricula m
    JOIN dbo.EvaExpediente e ON e.GuidMatricula = m.Guid
         AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
    JOIN dbo.EvaOferta o ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1
         AND o.Ejercicio BETWEEN 2010 AND 2020
    JOIN dbo.EvaExpedienteNota en1 ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion ev1 ON ev1.Guid = en1.GuidEvaluacion
         AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado IN ('A','C')
    JOIN dbo.EvaExpedienteNota enf ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion evf ON evf.Guid = enf.GuidEvaluacion
         AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado IN ('A','C')
    WHERE m.IsMatriculaPrincipal = 1
)
SELECT
    COALESCE(c.Ejercicio, s.Ejercicio)            AS Ejercicio,
    s.n_alumnos                                    AS sin_filtro_codigo,
    c.n_alumnos                                    AS con_filtro_codigo
FROM (SELECT Ejercicio, COUNT(DISTINCT GuidAlumno) AS n_alumnos FROM gate_sin_codigo GROUP BY Ejercicio) s
LEFT JOIN (SELECT Ejercicio, COUNT(DISTINCT GuidAlumno) AS n_alumnos FROM gate_con_codigo GROUP BY Ejercicio) c
    ON c.Ejercicio = s.Ejercicio
ORDER BY Ejercicio;
