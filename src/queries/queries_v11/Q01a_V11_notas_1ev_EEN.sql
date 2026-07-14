-- ============================================================================
-- Q01a_V11: Features 1EV — RAMA EEN (EvaExpedienteNota), TODOS los años
-- ============================================================================
-- Archivo STANDALONE — se corre solo (no UNION). Devuelve una fila por
-- (alumno, año, asignatura) con la nota de boletín de 1EV deduplicada.
--
-- FIX v11 vs v4:
--   Deduplicación: AVG(NotaNumerico) + MAX(IsAprobado) agrupando por
--   (alumno, año, asignatura). En v4 había hasta 62 rows por par, lo que
--   inflaba n_suspensos_1ev (el "alumno con 35 suspensos" del histograma).
--   Causa: múltiples EvaEvaluacion con Tipo='E', Numero=1 para la misma materia.
--
-- Columna n_raw_rows = nº de filas crudas colapsadas (>1 ⇒ había duplicados).
-- Para 2025, la mayoría de notas reales NO están aquí sino en EON (ver Q01b).
-- ============================================================================

WITH alumnos_validos AS (
    -- Alumnos con 1EV (EEN) + evaluación final (EEN). Sin filtro de año.
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
    ne.Nombre_Lng1              AS NivEstudio,
    nc.Nombre_Lng1              AS NivCurso,
    av.IsRepetidor,
    o.CodigoOficial             AS CodigoAsignatura,
    o.Nombre_Lng1               AS NombreAsignatura,
    AVG(en.NotaNumerico)        AS NotaNumerico,   -- promedio entre duplicados
    MAX(CAST(ec.IsAprobado AS INT)) AS IsAprobado, -- aprobado si alguna nota aprueba (bit→int para MAX)
    COUNT(*)                    AS n_raw_rows,     -- > 1 = había duplicados
    'EEN'                       AS fuente_nota
FROM alumnos_validos av
JOIN dbo.NivGrupo            ng  ON ng.Guid = av.GuidGrupo
JOIN dbo.NivCurso           nc  ON nc.Guid = ng.GuidCurso
JOIN dbo.NivEstudio         ne  ON ne.Guid = ng.GuidEstudio
JOIN dbo.EvaExpediente      e   ON e.GuidMatricula = av.GuidMatricula
                                AND e.NoMatriculado = 0
JOIN dbo.EvaOferta          o   ON o.Guid = e.GuidOferta
                                AND o.IsEvaluable = 1
JOIN dbo.EvaExpedienteNota  en  ON en.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = en.GuidEvaluacion
                                AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado = 'A'
LEFT JOIN dbo.EvaCalificacion ec
    ON  ec.Codigo                  = en.NotaCodigo
    AND ec.GuidTablaCalificaciones = o.GuidTablaCalificacionesOferta
GROUP BY
    av.GuidAlumno, av.Ejercicio, av.IsRepetidor,
    ne.Nombre_Lng1, nc.Nombre_Lng1,
    o.CodigoOficial, o.Nombre_Lng1
ORDER BY av.Ejercicio DESC, av.GuidAlumno, o.CodigoOficial;
