-- =============================================================================
-- Q_V4_02: Target — suspensos en la evaluación final (TODOS los años)
-- =============================================================================
-- Estrategia MAX(Numero): nota de la evaluación con Numero más alto (final real).
-- Target: suspensos=0→buen_alumno, 1-2→en_riesgo, 3+→con_dificultades
-- Sin filtro de año — incluye todos los ejercicios con ciclo completo.
-- =============================================================================

WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
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
),
numero_final_por_expediente AS (
    -- Número de evaluación más alto por expediente (la evaluación final real)
    SELECT
        e.Guid      AS GuidExpediente,
        MAX(ev.Numero)  AS numero_final
    FROM alumnos_validos av
    JOIN dbo.EvaExpediente       e   ON e.GuidMatricula = av.GuidMatricula
                                    AND e.NoMatriculado = 0
    JOIN dbo.EvaOferta           o   ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1
    JOIN dbo.EvaExpedienteNota   en  ON en.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       ev  ON ev.Guid = en.GuidEvaluacion
                                    AND ev.Tipo IN ('E','F')
                                    AND ev.Numero >= 3
                                    AND ev.Estado = 'A'
    GROUP BY e.Guid
),
nota_final AS (
    -- Nota efectiva en la evaluación final de cada expediente
    SELECT
        e.GuidMatricula,
        o.Ejercicio,
        ec.IsAprobado,
        en.NotaNumerico
    FROM numero_final_por_expediente nf
    JOIN dbo.EvaExpediente       e   ON e.Guid = nf.GuidExpediente
    JOIN dbo.EvaOferta           o   ON o.Guid = e.GuidOferta
    JOIN dbo.EvaExpedienteNota   en  ON en.GuidExpediente = nf.GuidExpediente
    JOIN dbo.EvaEvaluacion       ev  ON ev.Guid = en.GuidEvaluacion
                                    AND ev.Tipo IN ('E','F')
                                    AND ev.Numero = nf.numero_final
                                    AND ev.Estado = 'A'
    LEFT JOIN dbo.EvaCalificacion ec
        ON  ec.Codigo                  = en.NotaCodigo
        AND ec.GuidTablaCalificaciones = o.GuidTablaCalificacionesOferta
)
SELECT
    av.GuidAlumno,
    av.Ejercicio,
    COUNT(*)                                                            AS total_asignaturas,
    SUM(CASE WHEN nf.IsAprobado = 0 THEN 1 ELSE 0 END)                 AS suspensos,
    SUM(CASE WHEN nf.IsAprobado = 1 THEN 1 ELSE 0 END)                 AS aprobadas,
    AVG(nf.NotaNumerico)                                               AS nota_media_final,
    CASE
        WHEN SUM(CASE WHEN nf.IsAprobado = 0 THEN 1 ELSE 0 END) = 0             THEN 'buen_alumno'
        WHEN SUM(CASE WHEN nf.IsAprobado = 0 THEN 1 ELSE 0 END) BETWEEN 1 AND 2 THEN 'en_riesgo'
        ELSE 'con_dificultades'
    END                                                                 AS categoria_target
FROM alumnos_validos av
JOIN nota_final nf ON nf.GuidMatricula = av.GuidMatricula
                  AND nf.Ejercicio     = av.Ejercicio
GROUP BY av.GuidAlumno, av.Ejercicio
ORDER BY av.Ejercicio DESC, suspensos DESC, av.GuidAlumno;
