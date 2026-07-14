-- =============================================================================
-- Q_V4_01: Features — notas de boletín en 1ª evaluación (TODOS los años)
-- =============================================================================
-- Una fila por (alumno, asignatura) en la 1EV. Sin filtro de año.
-- Incluye GuidGrupo para join posterior con NivGrupo (nivel educativo)
-- una vez confirmados los nombres de campo con Q_v4_fix_schema_niv.sql.
-- Formato LONG — pivotar en pandas con pivot_table por CodigoAsignatura.
-- =============================================================================

WITH alumnos_validos AS (
    -- Alumnos con AMBAS evaluaciones: 1EV y evaluación final (Numero >= 3)
    -- Sin filtro de año — incluye todos los ejercicios con ciclo completo
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
        m.IdCentro,
        m.GuidGrupo,
        m.IsRepetidor,
        o.Ejercicio
    FROM dbo.Matricula           m
    JOIN dbo.EvaExpediente       e     ON e.GuidMatricula   = m.Guid
    JOIN dbo.EvaOferta           o     ON o.Guid            = e.GuidOferta
    JOIN dbo.EvaExpedienteNota   en1   ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       ev1   ON ev1.Guid = en1.GuidEvaluacion
                                      AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado = 'A'
    JOIN dbo.EvaExpedienteNota   enf   ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       evf   ON evf.Guid = enf.GuidEvaluacion
                                      AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado = 'A'
    WHERE m.IsMatriculaPrincipal = 1
      AND o.IsEvaluable = 1
      AND e.NoMatriculado = 0
)
SELECT
    av.GuidAlumno,
    av.Ejercicio,
    av.IdCentro,
    ne.Nombre_Lng1              AS NivEstudio,
    nc.Nombre_Lng1              AS NivCurso,
    av.IsRepetidor,
    o.CodigoOficial             AS CodigoAsignatura,
    o.Nombre_Lng1               AS NombreAsignatura,
    en.NotaCodigo,
    en.NotaNumerico,
    ec.IsAprobado
FROM alumnos_validos av
JOIN dbo.NivGrupo            ng  ON ng.Guid = av.GuidGrupo
JOIN dbo.NivCurso            nc  ON nc.Guid = ng.GuidCurso
JOIN dbo.NivEstudio          ne  ON ne.Guid = ng.GuidEstudio
JOIN dbo.EvaExpediente       e   ON e.GuidMatricula = av.GuidMatricula
                                AND e.NoMatriculado = 0
JOIN dbo.EvaOferta           o   ON o.Guid = e.GuidOferta
                                AND o.IsEvaluable = 1
JOIN dbo.EvaExpedienteNota   en  ON en.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion       ev  ON ev.Guid = en.GuidEvaluacion
                                AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado = 'A'
LEFT JOIN dbo.EvaCalificacion ec
    ON  ec.Codigo                  = en.NotaCodigo
    AND ec.GuidTablaCalificaciones = o.GuidTablaCalificacionesOferta
ORDER BY av.Ejercicio DESC, av.GuidAlumno, o.CodigoOficial;
