-- ============================================================================
-- QDIAG_18 — ¿Por qué un alumno tiene 34/49/69 asignaturas? (overcounting)
-- ============================================================================
-- Alumno de muestra con total=34 en 2020: 02A90042-FA44-0C95-E7FE-D5E89580D408
-- Distinguimos: (a) multi-matrícula vs (b) ofertas sub-granulares (áreas/competencias).
-- ============================================================================

-- ── PARTE A: schema de EvaOferta (buscar jerarquía padre/hijo o tipo) ────────
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EvaOferta'
ORDER BY ORDINAL_POSITION;

-- ── PARTE B: ¿cuántas matrículas principales tiene ese alumno en 2020? ──────
-- Si hay >1 fila → es multi-matrícula (el blocker). Si hay 1 con 34 ofertas →
-- es granularidad de ofertas.
SELECT
    m.Guid              AS GuidMatricula,
    m.IsMatriculaPrincipal,
    m.GuidGrupo,
    COUNT(DISTINCT e.GuidOferta) AS n_ofertas
FROM dbo.Matricula      m
JOIN dbo.EvaExpediente  e ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
JOIN dbo.EvaOferta      o ON o.Guid = e.GuidOferta AND o.Ejercicio = 2020 AND o.IsEvaluable = 1
WHERE m.GuidAlumno = '02A90042-FA44-0C95-E7FE-D5E89580D408'
GROUP BY m.Guid, m.IsMatriculaPrincipal, m.GuidGrupo;

-- ── PARTE C: listar las ofertas (asignaturas) que se le cuentan en la final ──
-- Los NOMBRES revelan si son materias reales o sub-áreas ("Lengua - Comprensión").
SELECT
    o.CodigoOficial,
    o.Nombre_Lng1,
    o.GuidTablaCalificacionesOferta,
    ev.Tipo, ev.Numero,
    COUNT(*) AS n_notas
FROM dbo.Matricula      m
JOIN dbo.EvaExpediente  e  ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
JOIN dbo.EvaOferta      o  ON o.Guid = e.GuidOferta AND o.Ejercicio = 2020 AND o.IsEvaluable = 1
JOIN dbo.EvaExpedienteNota en ON en.GuidExpediente = e.Guid
JOIN dbo.EvaEvaluacion  ev ON ev.Guid = en.GuidEvaluacion
                          AND ev.Tipo IN ('E','F') AND ev.Numero >= 3 AND ev.Estado = 'A'
WHERE m.GuidAlumno = '02A90042-FA44-0C95-E7FE-D5E89580D408'
  AND m.IsMatriculaPrincipal = 1
GROUP BY o.CodigoOficial, o.Nombre_Lng1, o.GuidTablaCalificacionesOferta, ev.Tipo, ev.Numero
ORDER BY o.CodigoOficial;
