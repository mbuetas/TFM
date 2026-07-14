-- ============================================================================
-- Q04_V11: Asistencia 1EV del cohorte (incidencias en la ventana sep-dic)
-- ============================================================================
-- Una fila por (alumno, año) CON alguna incidencia en 1EV. El assembly hace
-- LEFT JOIN y rellena 0 a los que no tienen registro.
-- Fuente: IncIncidenciaSesion (Fecha en sep-dic del Ejercicio = 1er trimestre).
-- JustificacionFecha NULL → falta NO justificada.
-- NOTA: la cobertura por año varía (años viejos pueden no tener sesiones
-- registradas); se mide en el assembly. Mismo gate que Q01/Q02.
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
-- Ponderacion (pedido del usuario): ausencia 1x, retraso 0.5x, expulsion 5x.
-- Se mantienen los 3 tipos relacionados con asistencia/conducta en clase y se
-- EXCLUYE comedor/servicios (SERV/EXTRA/NR), observaciones, material, siesta, etc.
SELECT
    sx.GuidAlumno,
    sx.Ejercicio,
    SUM(sx.peso)                                          AS total_incidencias_1ev,
    SUM(CASE WHEN sx.no_just = 1 THEN sx.peso ELSE 0 END) AS no_justificadas_1ev,
    SUM(CASE WHEN sx.no_just = 0 THEN sx.peso ELSE 0 END) AS justificadas_1ev
FROM (
    SELECT
        av.GuidAlumno, av.Ejercicio,
        CASE
            WHEN i.Nombre_Lng1 LIKE '%xpuls%'  OR i.Nombre_Lng2 LIKE '%xpuls%'  THEN 5.0
            WHEN i.Nombre_Lng1 LIKE '%bservac%' OR i.Nombre_Lng2 LIKE '%bservac%' THEN 2.0
            WHEN i.Nombre_Lng1 LIKE '%etras%' OR i.Nombre_Lng1 LIKE '%etard%'
              OR i.Nombre_Lng2 LIKE '%etras%' OR i.Nombre_Lng2 LIKE '%etard%' THEN 0.5
            WHEN i.Nombre_Lng1 LIKE '%usenc%' OR i.Nombre_Lng2 LIKE '%usenc%'
              OR i.Nombre_Lng1 LIKE '%bsen%'  OR i.Nombre_Lng2 LIKE '%bsen%'
              OR i.Nombre_Lng1 LIKE '%bs_nc%' OR i.Nombre_Lng2 LIKE '%bs_nc%' THEN 1.0
            ELSE 0 END                                            AS peso,
        CASE WHEN s.JustificacionFecha IS NULL THEN 1 ELSE 0 END  AS no_just
    FROM alumnos_validos av
    JOIN dbo.IncIncidenciaSesion s ON s.GuidMatricula = av.GuidMatricula
                                  AND YEAR(s.Fecha) = av.Ejercicio
                                  AND MONTH(s.Fecha) BETWEEN 9 AND 12
    JOIN dbo.IncIncidencia i ON i.Guid = s.GuidIncidencia
    WHERE i.CodSysEstudio NOT IN ('SERV','EXTRA','NR')
) sx
WHERE sx.peso > 0   -- descarta comedor / observaciones / material / siesta / etc.
GROUP BY sx.GuidAlumno, sx.Ejercicio
ORDER BY sx.Ejercicio DESC, sx.GuidAlumno;
