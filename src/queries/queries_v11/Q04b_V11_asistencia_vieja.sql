-- ============================================================================
-- Q04b_V11: Asistencia 1EV de años viejos (IncIncidenciaAcumulado, 2010-2016)
-- ============================================================================
-- IncIncidenciaSesion no cubre 2010/2011. IncIncidenciaAcumulado sí: conteos ya
-- agregados por (expediente, evaluación, tipo de incidencia).
-- Enlace: ia.GuidExpediente → EvaExpediente; ia.GuidEvaluacion → EvaEvaluacion (1EV).
-- Mismo formato de salida que Q04 (total/no_just/just) para concatenar en el assembly.
-- ============================================================================

WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
        o.Ejercicio
    FROM dbo.Matricula           m
    JOIN dbo.EvaExpediente       e     ON e.GuidMatricula   = m.Guid
                                      AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
    JOIN dbo.EvaOferta           o     ON o.Guid            = e.GuidOferta
                                      AND o.IsEvaluable = 1 AND o.Ejercicio <= 2020
                                      AND o.CodigoOficial IS NOT NULL
                                      AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
    JOIN dbo.EvaExpedienteNota   en1   ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       ev1   ON ev1.Guid = en1.GuidEvaluacion
                                      AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado IN ('A','C')
    JOIN dbo.EvaExpedienteNota   enf   ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       evf   ON evf.Guid = enf.GuidEvaluacion
                                      AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado IN ('A','C')
    WHERE m.IsMatriculaPrincipal = 1
)
-- Misma ponderacion que Q04: ausencia 1x, retraso 0.5x, expulsion 5x; excluye
-- comedor/servicios y tipos no relacionados. Aplica el peso a las cantidades
-- acumuladas (no/justificadas) de cada tipo de incidencia.
-- NOTA: requiere que IncIncidenciaAcumulado tenga GuidIncidencia (esquema estandar
-- Alexia). Si la columna no existiera, avisar para ajustar el enlace.
SELECT
    av.GuidAlumno,
    av.Ejercicio,
    SUM(w.peso * (ISNULL(ia.CantidadNoJustificada,0) + ISNULL(ia.CantidadJustificada,0))) AS total_incidencias_1ev,
    SUM(w.peso * ISNULL(ia.CantidadNoJustificada,0))                                      AS no_justificadas_1ev,
    SUM(w.peso * ISNULL(ia.CantidadJustificada,0))                                        AS justificadas_1ev
FROM alumnos_validos av
JOIN dbo.EvaExpediente      e  ON e.GuidMatricula = av.GuidMatricula
                              AND (e.NoMatriculado = 0 OR e.NoMatriculado IS NULL)
JOIN dbo.IncIncidenciaAcumulado ia ON ia.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion      ev ON ev.Guid = ia.GuidEvaluacion
                              AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado IN ('A','C')
JOIN dbo.IncIncidencia      i  ON i.Guid = ia.GuidIncidencia
                              AND i.CodSysEstudio NOT IN ('SERV','EXTRA','NR')
CROSS APPLY (SELECT CASE
        WHEN i.Nombre_Lng1 LIKE '%xpuls%'  OR i.Nombre_Lng2 LIKE '%xpuls%'  THEN 5.0
        WHEN i.Nombre_Lng1 LIKE '%bservac%' OR i.Nombre_Lng2 LIKE '%bservac%' THEN 2.0
        WHEN i.Nombre_Lng1 LIKE '%etras%' OR i.Nombre_Lng1 LIKE '%etard%'
          OR i.Nombre_Lng2 LIKE '%etras%' OR i.Nombre_Lng2 LIKE '%etard%' THEN 0.5
        WHEN i.Nombre_Lng1 LIKE '%usenc%' OR i.Nombre_Lng2 LIKE '%usenc%'
          OR i.Nombre_Lng1 LIKE '%bsen%'  OR i.Nombre_Lng2 LIKE '%bsen%'
          OR i.Nombre_Lng1 LIKE '%bs_nc%' OR i.Nombre_Lng2 LIKE '%bs_nc%' THEN 1.0
        ELSE 0 END AS peso) w
WHERE w.peso > 0
GROUP BY av.GuidAlumno, av.Ejercicio
ORDER BY av.Ejercicio DESC, av.GuidAlumno;
