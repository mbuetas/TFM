-- ============================================================================
-- QDIAG_22 — Previsualizar el dataset bajo el gate nuevo (Estado A/C)
-- ============================================================================
-- Cuenta alumnos por año que pasan el gate (1EV + final), en 2 variantes:
--   A) con filtro de asignatura real (CodigoOficial no vacío)
--   B) sin ese filtro
-- Si para 2012-2017 B >> A, el filtro de código rompe esos años (códigos en
-- blanco como en 2010) y hay que usar otro discriminador.
-- ============================================================================

-- ── VARIANTE A: gate nuevo CON filtro de código ─────────────────────────────
WITH gate_A AS (
    SELECT DISTINCT m.GuidAlumno, o.Ejercicio
    FROM dbo.Matricula m
    JOIN dbo.EvaExpediente e ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
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
)
SELECT 'A_con_filtro_codigo' AS variante, Ejercicio, COUNT(DISTINCT GuidAlumno) AS n_alumnos
FROM gate_A GROUP BY Ejercicio

UNION ALL

-- ── VARIANTE B: gate nuevo SIN filtro de código ─────────────────────────────
SELECT 'B_sin_filtro_codigo' AS variante, z.Ejercicio, COUNT(DISTINCT z.GuidAlumno) AS n_alumnos
FROM (
    SELECT DISTINCT m.GuidAlumno, o.Ejercicio
    FROM dbo.Matricula m
    JOIN dbo.EvaExpediente e ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
    JOIN dbo.EvaOferta o ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1
         AND o.Ejercicio BETWEEN 2010 AND 2020
    JOIN dbo.EvaExpedienteNota en1 ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion ev1 ON ev1.Guid = en1.GuidEvaluacion
         AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado IN ('A','C')
    JOIN dbo.EvaExpedienteNota enf ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion evf ON evf.Guid = enf.GuidEvaluacion
         AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado IN ('A','C')
    WHERE m.IsMatriculaPrincipal = 1
) z
GROUP BY z.Ejercicio

ORDER BY Ejercicio, variante;
