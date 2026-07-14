-- ============================================================================
-- QDIAG_10 — Validar EvaAspectoNota como fuente de 1EV para Bachillerato 2025
-- ============================================================================
-- EvaAspectoNota (competencias clave) tiene las 15 asignaturas de Bach 2025.
-- Antes de reconstruir la nota de asignatura hay que confirmar:
--   A) Escala de NotaNumerico (¿0-10 como el resto de años?) y cobertura/asig.
--   B) Cobertura en Primaria (confirmar que solo hay 2 asignaturas).
--   C) Qué son los "aspectos" que promediamos (Tipo + nombre).
-- ============================================================================

-- ── PARTE A: Bachillerato — por asignatura: cobertura + escala ───────────────
SELECT
    o.CodigoOficial                                         AS CodigoAsignatura,
    o.Nombre_Lng1                                           AS Asignatura,
    COUNT(DISTINCT m.GuidAlumno)                            AS n_alumnos,
    COUNT(DISTINCT an.GuidAspecto)                          AS n_aspectos,
    COUNT(*)                                                AS n_notas,
    SUM(CASE WHEN an.NotaNumerico IS NULL THEN 1 ELSE 0 END) AS n_notas_null,
    MIN(an.NotaNumerico)                                    AS nota_min,
    MAX(an.NotaNumerico)                                    AS nota_max,
    AVG(an.NotaNumerico)                                    AS nota_avg
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = an.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = an.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 = 'Bachillerato'
GROUP BY o.CodigoOficial, o.Nombre_Lng1
ORDER BY n_alumnos DESC, Asignatura;

-- ── PARTE B: Primaria — mismo desglose (confirmar que solo hay ~2 asig) ──────
SELECT
    o.CodigoOficial                                         AS CodigoAsignatura,
    o.Nombre_Lng1                                           AS Asignatura,
    COUNT(DISTINCT m.GuidAlumno)                            AS n_alumnos,
    COUNT(DISTINCT an.GuidAspecto)                          AS n_aspectos,
    COUNT(*)                                                AS n_notas,
    MIN(an.NotaNumerico)                                    AS nota_min,
    MAX(an.NotaNumerico)                                    AS nota_max,
    AVG(an.NotaNumerico)                                    AS nota_avg
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = an.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = an.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 = 'Educación Primaria'
GROUP BY o.CodigoOficial, o.Nombre_Lng1
ORDER BY n_alumnos DESC, Asignatura;

-- ── PARTE C: ¿qué son los aspectos? Primero el schema de EvaAspecto ─────────
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EvaAspecto'
ORDER BY ORDINAL_POSITION;

-- Aspectos por nombre para Bachillerato 2025 (sin Tipo: esa columna no existe)
SELECT
    asp.Nombre_Lng1                                         AS NombreAspecto,
    COUNT(DISTINCT an.GuidExpediente)                       AS n_expedientes,
    COUNT(*)                                                AS n_notas,
    MIN(an.NotaNumerico)                                    AS nota_min,
    MAX(an.NotaNumerico)                                    AS nota_max
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaAspecto     asp ON asp.Guid = an.GuidAspecto
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = an.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = an.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 = 'Bachillerato'
GROUP BY asp.Nombre_Lng1
ORDER BY n_notas DESC;
