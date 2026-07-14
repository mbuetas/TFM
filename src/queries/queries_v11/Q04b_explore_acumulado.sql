-- ============================================================================
-- Q04b (exploración) — IncIncidenciaAcumulado para recuperar asistencia 2010-2016
-- ============================================================================
-- IncIncidenciaSesion no cubre 2010/2011. IncIncidenciaAcumulado sí (hasta 2016).
-- Primero entendemos su estructura para escribir la query de asistencia definitiva.
-- ============================================================================

-- ── PARTE A: columnas de IncIncidenciaAcumulado ─────────────────────────────
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'IncIncidenciaAcumulado'
ORDER BY ORDINAL_POSITION;

-- ── PARTE B: muestra de 20 filas ────────────────────────────────────────────
SELECT TOP 20 * FROM dbo.IncIncidenciaAcumulado;

-- ── PARTE C: cobertura por año (asumiendo GuidMatricula; si falla, lo ajusto) ─
SELECT
    o.Ejercicio,
    COUNT(DISTINCT m.GuidAlumno) AS n_alumnos_con_acumulado
FROM dbo.IncIncidenciaAcumulado ia
JOIN dbo.Matricula      m ON m.Guid = ia.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.EvaExpediente  e ON e.GuidMatricula = m.Guid
JOIN dbo.EvaOferta      o ON o.Guid = e.GuidOferta AND o.Ejercicio BETWEEN 2010 AND 2020
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;
