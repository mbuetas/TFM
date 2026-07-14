-- ============================================================================
-- Q01_V11: Features — notas de 1EV (años recuperables ≤2020), VERSIÓN FINAL
-- ============================================================================
-- Una fila por (alumno, año, asignatura) con la nota de boletín de 1EV.
--
-- Mejoras V11:
--  · Resolución de nota vía EvaCalificacion (código → Valor + IsAprobado),
--    con NotaNumerico de respaldo → capta también notas cualitativas
--    (Primaria SB/NT/BI/IN), sin perder asignaturas.
--  · Deduplicación: AVG(valor) por (alumno, año, asignatura) → arregla el bug
--    de duplicados que inflaba n_suspensos. IsAprobado dedup = MIN (conservador:
--    suspenso si alguna evaluación 1EV de esa materia suspende).
--  · Solo años con datos densos (Ejercicio <= 2020). 2021-2025 no tienen 1EV.
--  · OUTER APPLY TOP 1 a EvaCalificacion → evita fan-out si (Codigo,GuidTabla)
--    no fuese único.
--
-- Formato LONG — pivotar en pandas. NivEstudio/NivCurso para filtrar Infantil/CF
-- en el assembly (NO aquí).
-- ============================================================================

WITH alumnos_validos AS (
    -- Cohorte: alumnos con 1EV (EEN E/1) Y evaluación final (EEN E/F, Numero>=3),
    -- en años con datos (<=2020).
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
                                      AND o.IsEvaluable = 1 AND o.Ejercicio <= 2020
                                      -- solo asignaturas reales (no observaciones/IB/sub-áreas)
                                      AND o.CodigoOficial IS NOT NULL
                                      AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
    JOIN dbo.EvaExpedienteNota   en1   ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       ev1   ON ev1.Guid = en1.GuidEvaluacion
                                      AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado IN ('A','C')
    JOIN dbo.EvaExpedienteNota   enf   ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       evf   ON evf.Guid = enf.GuidEvaluacion
                                      AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado IN ('A','C')
    WHERE m.IsMatriculaPrincipal = 1
      AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
)
SELECT
    av.GuidAlumno,
    av.Ejercicio,
    ne.Nombre_Lng1                                                     AS NivEstudio,
    nc.Nombre_Lng1                                                     AS NivCurso,
    av.IsRepetidor,
    o.CodigoOficial                                                    AS CodigoAsignatura,
    o.Nombre_Lng1                                                      AS NombreAsignatura,
    AVG(COALESCE(cal.Valor, en.NotaNumerico))                          AS NotaNumerico,
    -- IsAprobado coherente con la nota promediada (evita AVG=5 marcado suspenso).
    -- NULL = sin nota resoluble (NP/Acta) → el assembly lo trata como no calificada.
    CASE WHEN AVG(COALESCE(cal.Valor, en.NotaNumerico)) >= 5 THEN 1
         WHEN AVG(COALESCE(cal.Valor, en.NotaNumerico)) <  5 THEN 0
         ELSE NULL END                                                 AS IsAprobado,
    COUNT(*)                                                           AS n_raw_rows
FROM alumnos_validos av
-- LEFT JOIN: el nivel es atributo categórico, NO debe recortar el universo
LEFT JOIN dbo.NivGrupo      ng  ON ng.Guid = av.GuidGrupo
LEFT JOIN dbo.NivCurso      nc  ON nc.Guid = ng.GuidCurso
LEFT JOIN dbo.NivEstudio    ne  ON ne.Guid = ng.GuidEstudio
JOIN dbo.EvaExpediente      e   ON e.GuidMatricula = av.GuidMatricula
                                AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
JOIN dbo.EvaOferta          o   ON o.Guid = e.GuidOferta
                                AND o.IsEvaluable = 1
                                AND o.Ejercicio = av.Ejercicio          -- reata el año (anti-mezcla)
                                AND o.CodigoOficial IS NOT NULL          -- solo asignaturas reales
                                AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
JOIN dbo.EvaExpedienteNota  en  ON en.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = en.GuidEvaluacion
                                AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado IN ('A','C')
OUTER APPLY (
    SELECT TOP 1 ec.Valor, ec.IsAprobado
    FROM dbo.EvaCalificacion ec
    WHERE ec.Codigo = en.NotaCodigo
      AND ec.GuidTablaCalificaciones = o.GuidTablaCalificacionesOferta
) cal
GROUP BY
    av.GuidAlumno, av.Ejercicio, av.IsRepetidor,
    ne.Nombre_Lng1, nc.Nombre_Lng1,
    o.CodigoOficial, o.Nombre_Lng1
ORDER BY av.Ejercicio DESC, av.GuidAlumno, o.CodigoOficial;
