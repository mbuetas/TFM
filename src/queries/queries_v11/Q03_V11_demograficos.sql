-- ============================================================================
-- Q03_V11: Demografía del cohorte (mismo gate que Q01/Q02 → 1.274 alumnos-año)
-- ============================================================================
-- Una fila por (alumno, año). Joins: Matricula → ComunAlumno → ComunPersona.
-- NacimientoFecha se exporta cruda; edad_relativa/mes/trimestre se calculan en
-- el assembly (pandas). Mismos fixes: NoMatriculado NULL-safe, Estado A/C, <=2020.
-- ============================================================================

WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
        m.GuidGrupo,
        m.IsRepetidor,
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
),
-- 1 matrícula por (alumno, año) por si hubiera doble matrícula principal
av_unico AS (
    SELECT GuidAlumno, GuidMatricula, GuidGrupo, IsRepetidor, Ejercicio
    FROM (
        SELECT av.*,
               ROW_NUMBER() OVER (PARTITION BY GuidAlumno, Ejercicio ORDER BY GuidMatricula DESC) AS rn
        FROM alumnos_validos av
    ) z
    WHERE rn = 1
)
SELECT DISTINCT
    av.GuidAlumno,
    av.Ejercicio,
    ne.Nombre_Lng1              AS NivEstudio,
    nc.Nombre_Lng1              AS NivCurso,
    cp.Sexo,
    cp.NacimientoFecha,
    cp.IdNacionalidad1,
    av.IsRepetidor,
    ca.IdNEE,
    ca.HermanosPosicion
FROM av_unico av
LEFT JOIN dbo.ComunAlumno    ca  ON ca.Guid = av.GuidAlumno
LEFT JOIN dbo.ComunPersona   cp  ON cp.Guid = ca.GuidPersona
LEFT JOIN dbo.NivGrupo       ng  ON ng.Guid = av.GuidGrupo
LEFT JOIN dbo.NivCurso       nc  ON nc.Guid = ng.GuidCurso
LEFT JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
ORDER BY av.Ejercicio DESC, av.GuidAlumno;
