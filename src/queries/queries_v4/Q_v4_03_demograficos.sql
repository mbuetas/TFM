-- =============================================================================
-- Q_V4_03: Datos demográficos — todos los años con ciclo completo
-- =============================================================================
-- Una fila por (alumno, año). Sin filtro de año.
-- Join correcto: Matricula.GuidAlumno → ComunAlumno.Guid → ComunPersona.Guid
-- La edad se calcula al inicio del curso (1 septiembre del año Ejercicio-1).
-- =============================================================================

WITH alumnos_validos AS (
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
    cp.Sexo,
    cp.NacimientoFecha,
    -- Edad al 1 de septiembre del inicio del curso
    -- Ejercicio=2019 → curso 2018-19 → inicio = 01/09/2018
    DATEDIFF(year,
             cp.NacimientoFecha,
             DATEFROMPARTS(av.Ejercicio - 1, 9, 1))
    - CASE
        WHEN MONTH(cp.NacimientoFecha) > 9
          OR (MONTH(cp.NacimientoFecha) = 9 AND DAY(cp.NacimientoFecha) > 1)
        THEN 1 ELSE 0
      END                       AS Edad_inicio_curso,
    cp.IdNacionalidad1,
    cp.Minusvalia,
    av.IsRepetidor,
    ca.IdNEE,
    ca.HermanosPosicion
FROM alumnos_validos av
JOIN dbo.NivGrupo      ng  ON ng.Guid         = av.GuidGrupo
JOIN dbo.NivCurso      nc  ON nc.Guid         = ng.GuidCurso
JOIN dbo.NivEstudio    ne  ON ne.Guid         = ng.GuidEstudio
JOIN dbo.ComunAlumno   ca  ON ca.Guid         = av.GuidAlumno
JOIN dbo.ComunPersona  cp  ON cp.Guid         = ca.GuidPersona
ORDER BY av.Ejercicio DESC, av.GuidAlumno;
