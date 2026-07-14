-- ============================================================================
-- Q02_V11: Target — suspensos en evaluación final (años ≤2020), VERSIÓN FINAL
-- ============================================================================
-- Una fila por (alumno, año). Target: 0 susp → buen_alumno | 1-2 → en_riesgo |
-- 3+ → con_dificultades.
--
-- Mejoras V11:
--  · Selección DETERMINISTA de la nota final por asignatura: ROW_NUMBER
--    priorizando Tipo='F' (final oficial) sobre 'E', luego Numero más alto.
--    Evita el sesgo optimista de MAX(IsAprobado) que inflaba 'buen_alumno'.
--  · Resolución vía EvaCalificacion (código → IsAprobado + Valor), respaldo
--    NotaNumerico>=5 → maneja notas cualitativas (Primaria) correctamente.
--  · Solo años con datos densos (Ejercicio <= 2020).
-- ============================================================================

WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
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
),
final_rows AS (
    -- Todas las notas candidatas a "final" por expediente (asignatura)
    SELECT
        e.GuidMatricula,
        e.Guid                          AS GuidExpediente,
        o.Ejercicio,
        en.Guid                         AS GuidNota,
        en.NotaCodigo,
        en.NotaNumerico,
        o.GuidTablaCalificacionesOferta AS GuidTabla,
        ev.Tipo,
        ev.Numero
    FROM alumnos_validos av
    JOIN dbo.EvaExpediente     e   ON e.GuidMatricula = av.GuidMatricula AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
    JOIN dbo.EvaOferta         o   ON o.Guid = e.GuidOferta
                                  AND o.IsEvaluable = 1
                                  AND o.Ejercicio = av.Ejercicio
                                  AND o.CodigoOficial IS NOT NULL        -- solo asignaturas reales
                                  AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
    JOIN dbo.EvaExpedienteNota en  ON en.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion     ev  ON ev.Guid = en.GuidEvaluacion
                                  AND ev.Tipo IN ('E','F') AND ev.Numero >= 3 AND ev.Estado IN ('A','C')
),
final_pick AS (
    -- 1 nota final por asignatura: F antes que E, mayor Numero, desempate estable
    SELECT
        fr.*,
        ROW_NUMBER() OVER (
            PARTITION BY fr.GuidExpediente
            ORDER BY CASE WHEN fr.Tipo = 'F' THEN 0 ELSE 1 END,
                     fr.Numero DESC,
                     fr.GuidNota DESC
        ) AS rn
    FROM final_rows fr
),
final_resuelto AS (
    SELECT
        fp.GuidMatricula,
        fp.Ejercicio,
        -- NULL = nota no resoluble (NP/Acta/código sin mapa). NO se cuenta como
        -- suspenso (evita inflar el target con asignaturas no calificadas).
        COALESCE(cal.IsAprobado,
                 CASE WHEN fp.NotaNumerico >= 5 THEN 1
                      WHEN fp.NotaNumerico <  5 THEN 0
                      ELSE NULL END)                                    AS IsAprobado,
        COALESCE(cal.Valor, fp.NotaNumerico)                           AS NotaNumerico
    FROM final_pick fp
    OUTER APPLY (
        SELECT TOP 1 ec.Valor, ec.IsAprobado
        FROM dbo.EvaCalificacion ec
        WHERE ec.Codigo = fp.NotaCodigo
          AND ec.GuidTablaCalificaciones = fp.GuidTabla
    ) cal
    WHERE fp.rn = 1
)
SELECT
    av.GuidAlumno,
    av.Ejercicio,
    COUNT(*)                                                           AS total_asignaturas,
    SUM(CASE WHEN fr.IsAprobado = 0 THEN 1 ELSE 0 END)                 AS suspensos,
    SUM(CASE WHEN fr.IsAprobado = 1 THEN 1 ELSE 0 END)                 AS aprobadas,
    SUM(CASE WHEN fr.IsAprobado IS NULL THEN 1 ELSE 0 END)             AS n_no_resueltas,
    AVG(fr.NotaNumerico)                                               AS nota_media_final,
    CASE
        WHEN SUM(CASE WHEN fr.IsAprobado = 0 THEN 1 ELSE 0 END) = 0              THEN 'buen_alumno'
        WHEN SUM(CASE WHEN fr.IsAprobado = 0 THEN 1 ELSE 0 END) BETWEEN 1 AND 2  THEN 'en_riesgo'
        ELSE 'con_dificultades'
    END                                                                 AS categoria_target
FROM alumnos_validos av
JOIN final_resuelto fr ON fr.GuidMatricula = av.GuidMatricula
                      AND fr.Ejercicio     = av.Ejercicio
GROUP BY av.GuidAlumno, av.Ejercicio
ORDER BY av.Ejercicio DESC, suspensos DESC, av.GuidAlumno;
