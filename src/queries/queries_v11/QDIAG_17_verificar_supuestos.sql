-- ============================================================================
-- QDIAG_17 — Verificar supuestos de Q01/Q02 V11 antes de extraer
-- ============================================================================
-- 3 chequeos que la revisión marcó como pendientes de confirmar con datos.
-- ============================================================================

-- ── CHEQUEO 1: ¿EvaExpedienteNota tiene columna Guid (PK)? ───────────────────
-- Q02 usa en.Guid para el desempate del ROW_NUMBER. Si esto corre, existe.
SELECT TOP 1 Guid FROM dbo.EvaExpedienteNota;

-- ── CHEQUEO 2 (BLOCKER): ¿hay >1 matrícula principal por (alumno, año)? ──────
-- Si devuelve filas, Q02 fusionaría dos matrículas en un target y el merge
-- en pandas dejaría de ser 1:1 → habría que colapsar a 1 matrícula por (alumno,año).
WITH alumnos_validos AS (
    SELECT DISTINCT
        m.GuidAlumno,
        m.Guid       AS GuidMatricula,
        o.Ejercicio
    FROM dbo.Matricula           m
    JOIN dbo.EvaExpediente       e     ON e.GuidMatricula   = m.Guid
    JOIN dbo.EvaOferta           o     ON o.Guid            = e.GuidOferta
                                      AND o.IsEvaluable = 1 AND o.Ejercicio <= 2020
    JOIN dbo.EvaExpedienteNota   en1   ON en1.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       ev1   ON ev1.Guid = en1.GuidEvaluacion
                                      AND ev1.Tipo = 'E' AND ev1.Numero = 1 AND ev1.Estado = 'A'
    JOIN dbo.EvaExpedienteNota   enf   ON enf.GuidExpediente = e.Guid
    JOIN dbo.EvaEvaluacion       evf   ON evf.Guid = enf.GuidEvaluacion
                                      AND evf.Tipo IN ('E','F') AND evf.Numero >= 3 AND evf.Estado = 'A'
    WHERE m.IsMatriculaPrincipal = 1
      AND e.NoMatriculado = 0
)
SELECT
    GuidAlumno,
    Ejercicio,
    COUNT(DISTINCT GuidMatricula) AS n_matriculas
FROM alumnos_validos
GROUP BY GuidAlumno, Ejercicio
HAVING COUNT(DISTINCT GuidMatricula) > 1
ORDER BY n_matriculas DESC;

-- ── CHEQUEO 3: ¿cuántas notas FINALES no resuelven contra EvaCalificacion? ──
-- Mide el caso NP/Acta/código sin mapa (las que ahora quedan como IsAprobado NULL).
SELECT
    o.Ejercicio,
    COUNT(*)                                                          AS n_notas_final,
    SUM(CASE WHEN ec.Codigo IS NULL THEN 1 ELSE 0 END)                AS n_sin_match_calif,
    SUM(CASE WHEN ec.Codigo IS NULL AND en.NotaNumerico IS NULL THEN 1 ELSE 0 END) AS n_no_resolubles
FROM dbo.EvaExpediente      e
JOIN dbo.EvaOferta          o   ON o.Guid = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio <= 2020
JOIN dbo.Matricula          m   ON m.Guid = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.EvaExpedienteNota  en  ON en.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = en.GuidEvaluacion
                                AND ev.Tipo IN ('E','F') AND ev.Numero >= 3 AND ev.Estado = 'A'
LEFT JOIN dbo.EvaCalificacion ec
    ON  ec.Codigo                  = en.NotaCodigo
    AND ec.GuidTablaCalificaciones = o.GuidTablaCalificacionesOferta
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;
