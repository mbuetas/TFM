-- ============================================================================
-- Q01b_V11: Features 1EV — RAMA EON (EvaObjetivoNota), LOMLOE, SOLO 2025
-- ============================================================================
-- Archivo STANDALONE — se corre solo (no UNION). Reconstruye la nota de 1EV
-- de cada asignatura para los alumnos LOMLOE de 2025, promediando sus
-- criterios de evaluación (EvaObjetivo TipoObjetivo=7).
--
-- POR QUÉ: en 2025 las notas de 1EV de Primaria/Bachillerato NO están en
-- EvaExpedienteNota (solo 1.3 filas/alumno — ver QDIAG_02) sino en
-- EvaObjetivoNota (18.9 filas/alumno). Esto causaba que las features de 2025
-- se construyeran sobre 1 asignatura aleatoria → patrón invertido en el EDA.
--
-- Cadena de joins (clave del fix):
--   EvaObjetivoNota.GuidObjetivo_Evaluacion → EvaObjetivo_Evaluacion.Guid
--   EvaObjetivo_Evaluacion.GuidObjetivo     → EvaObjetivo.Guid (TipoObjetivo=7)
--   EvaObjetivo_Evaluacion.GuidEvaluacion   → EvaEvaluacion (Tipo='E', Numero=1)
--
-- Mismo universo alumnos_validos que Q01a / Q02 (consistencia para el merge).
-- En pandas: para 2025, si una asignatura aparece en EEN y EON, preferir EON.
-- ============================================================================

WITH alumnos_validos AS (
    -- Idéntico a Q01a — mismo universo de alumnos para que el merge cuadre.
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
    o.Ejercicio,
    ne.Nombre_Lng1                                        AS NivEstudio,
    nc.Nombre_Lng1                                        AS NivCurso,
    av.IsRepetidor,
    o.CodigoOficial                                       AS CodigoAsignatura,
    o.Nombre_Lng1                                         AS NombreAsignatura,
    AVG(eon.NotaValor)                                    AS NotaNumerico,   -- media de criterios
    CASE WHEN AVG(eon.NotaValor) >= 5 THEN 1 ELSE 0 END   AS IsAprobado,     -- umbral 5/10
    COUNT(*)                                              AS n_raw_rows,     -- nº de criterios
    'EON'                                                 AS fuente_nota
FROM alumnos_validos av
JOIN dbo.EvaExpediente          e   ON e.GuidMatricula = av.GuidMatricula
                                    AND e.NoMatriculado = 0
JOIN dbo.EvaObjetivoNota        eon ON eon.GuidExpediente = e.Guid
                                    AND eon.NotaValor IS NOT NULL
JOIN dbo.EvaObjetivo_Evaluacion oev ON oev.Guid = eon.GuidObjetivo_Evaluacion
JOIN dbo.EvaObjetivo            ob  ON ob.Guid = oev.GuidObjetivo
                                    AND ob.TipoObjetivo = 7            -- criterios LOMLOE
                                    AND ob.GuidOferta = e.GuidOferta   -- criterio de ESTA asignatura
JOIN dbo.EvaEvaluacion          ev  ON ev.Guid = oev.GuidEvaluacion
                                    AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado = 'A'
JOIN dbo.EvaOferta              o   ON o.Guid = e.GuidOferta
                                    AND o.IsEvaluable = 1
JOIN dbo.NivGrupo               ng  ON ng.Guid = av.GuidGrupo
JOIN dbo.NivCurso               nc  ON nc.Guid = ng.GuidCurso
JOIN dbo.NivEstudio             ne  ON ne.Guid = ng.GuidEstudio
WHERE av.Ejercicio = 2025
GROUP BY
    av.GuidAlumno, o.Ejercicio, av.IsRepetidor,
    ne.Nombre_Lng1, nc.Nombre_Lng1,
    o.CodigoOficial, o.Nombre_Lng1
ORDER BY av.GuidAlumno, o.CodigoOficial;
