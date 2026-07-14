-- =============================================================================
-- Q_V4_00: Diagnóstico — cobertura por año y asistencia histórica
-- =============================================================================
-- Ejecutar ANTES de Q_v4_01 a Q_v4_04.
-- NOTA: join a NivGrupo/NivCurso/NivEstudio PENDIENTE (ver Q_v4_fix_schema_niv.sql)
-- =============================================================================


-- ─── BLOQUE 1: Alumnos con datos completos (1EV + final) por ejercicio y nivel ─
-- Sin filtro de año. Muestra cuántos alumnos por año y nivel educativo tienen
-- el ciclo completo. Permite ver cuántos son ESO/Bach vs Primaria/Infantil.

WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.IdCentro,
        m.GuidGrupo,
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
    av.Ejercicio,
    av.IdCentro,
    ne.Nombre_Lng1              AS NivEstudio,
    nc.Nombre_Lng1              AS NivCurso,
    COUNT(DISTINCT av.GuidAlumno) AS alumnos
FROM alumnos_validos av
JOIN dbo.NivGrupo    ng  ON ng.Guid = av.GuidGrupo
JOIN dbo.NivCurso    nc  ON nc.Guid = ng.GuidCurso
JOIN dbo.NivEstudio  ne  ON ne.Guid = ng.GuidEstudio
GROUP BY av.Ejercicio, av.IdCentro, ne.Nombre_Lng1, nc.Nombre_Lng1
ORDER BY av.Ejercicio DESC, alumnos DESC;


-- ─── BLOQUE 2: Cobertura de IncIncidenciaAcumulado por año ───────────────────
-- ¿Hay datos de faltas para años históricos? Todos los años sin filtro.

SELECT
    o.Ejercicio,
    ev.Tipo,
    ev.Numero,
    COUNT(*)                            AS registros,
    COUNT(DISTINCT m.GuidAlumno)        AS alumnos_con_faltas
FROM dbo.IncIncidenciaAcumulado  ia
JOIN dbo.EvaExpediente           e   ON e.Guid        = ia.GuidExpediente
JOIN dbo.EvaOferta               o   ON o.Guid        = e.GuidOferta
JOIN dbo.EvaEvaluacion           ev  ON ev.Guid       = ia.GuidEvaluacion
JOIN dbo.Matricula               m   ON m.Guid        = e.GuidMatricula
WHERE m.IsMatriculaPrincipal = 1
  AND o.IsEvaluable = 1
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero
ORDER BY o.Ejercicio DESC, ev.Numero;
