-- ============================================================================
-- QDIAG_05 — Cobertura de asignaturas 2025: EEN vs EON sobre el universo
-- ============================================================================
-- Objetivo: confirmar que el universo alumnos_validos (gate por EEN 1EV + final)
-- captura a los alumnos LOMLOE de 2025, y cuántas asignaturas de 1EV recupera
-- cada fuente. Esperado: EON ~12 asig/alumno, EEN ~1-2 asig/alumno.
--
-- Si algún alumno de 2025 del universo tiene 0 asignaturas EON, revisar el gate.
-- ============================================================================

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
universo_2025 AS (
    SELECT DISTINCT GuidAlumno, GuidMatricula
    FROM alumnos_validos
    WHERE Ejercicio = 2025
),
-- Asignaturas distintas de 1EV vía EEN, por alumno
cob_een AS (
    SELECT u.GuidAlumno, COUNT(DISTINCT e.GuidOferta) AS n_asig_een
    FROM universo_2025 u
    JOIN dbo.EvaExpediente     e   ON e.GuidMatricula = u.GuidMatricula AND e.NoMatriculado = 0
    JOIN dbo.EvaOferta         o   ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1
    JOIN dbo.EvaExpedienteNota en  ON en.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion     ev  ON ev.Guid = en.GuidEvaluacion
                                  AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado = 'A'
    GROUP BY u.GuidAlumno
),
-- Asignaturas distintas de 1EV vía EON, por alumno
cob_eon AS (
    SELECT u.GuidAlumno, COUNT(DISTINCT e.GuidOferta) AS n_asig_eon
    FROM universo_2025 u
    JOIN dbo.EvaExpediente          e   ON e.GuidMatricula = u.GuidMatricula AND e.NoMatriculado = 0
    JOIN dbo.EvaObjetivoNota        eon ON eon.GuidExpediente = e.Guid AND eon.NotaValor IS NOT NULL
    JOIN dbo.EvaObjetivo_Evaluacion oev ON oev.Guid = eon.GuidObjetivo_Evaluacion
    JOIN dbo.EvaObjetivo            ob  ON ob.Guid = oev.GuidObjetivo AND ob.TipoObjetivo = 7
    JOIN dbo.EvaEvaluacion          ev  ON ev.Guid = oev.GuidEvaluacion
                                       AND ev.Tipo = 'E' AND ev.Numero = 1 AND ev.Estado = 'A'
    GROUP BY u.GuidAlumno
)
SELECT
    (SELECT COUNT(*) FROM universo_2025)                                  AS alumnos_universo_2025,
    (SELECT COUNT(*) FROM cob_een)                                        AS alumnos_con_EEN_1ev,
    (SELECT COUNT(*) FROM cob_eon)                                        AS alumnos_con_EON_1ev,
    (SELECT AVG(CAST(n_asig_een AS FLOAT)) FROM cob_een)                  AS media_asig_EEN,
    (SELECT AVG(CAST(n_asig_eon AS FLOAT)) FROM cob_eon)                  AS media_asig_EON,
    (SELECT COUNT(*) FROM universo_2025 u
       WHERE NOT EXISTS (SELECT 1 FROM cob_eon c WHERE c.GuidAlumno = u.GuidAlumno))
                                                                          AS alumnos_SIN_EON;
