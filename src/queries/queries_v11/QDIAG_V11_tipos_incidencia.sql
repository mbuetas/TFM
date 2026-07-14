-- ============================================================================
-- QDIAG_V11 — Tipos de incidencia en la ventana 1EV (separar comedor de clase)
-- ============================================================================
-- Q04 hoy cuenta TODAS las sesiones de IncIncidenciaSesion (comedor, agenda,
-- conducta, faltas...). Queremos quedarnos SOLO con inasistencias a clase /
-- actividades. Este diagnóstico enumera los tipos del catálogo IncIncidencia
-- que aparecen en sep-dic, con su volumen, para decidir cuáles conservar.
-- ============================================================================

-- ── PARTE A: catálogo completo de tipos (revela columnas y nombres) ──────────
SELECT TOP 200 * FROM dbo.IncIncidencia ORDER BY 1;

-- ── PARTE B: tipos que REALMENTE aparecen en la ventana 1EV (sep-dic) ────────
-- Ordenados por volumen. Con el nombre (de Parte A) decidimos comedor vs clase.
SELECT
    s.GuidIncidencia,
    COUNT(*)                          AS n_sesiones,
    COUNT(DISTINCT s.GuidMatricula)   AS n_alumnos,
    MIN(s.Fecha)                      AS primera,
    MAX(s.Fecha)                      AS ultima
FROM dbo.IncIncidenciaSesion s
WHERE MONTH(s.Fecha) BETWEEN 9 AND 12
GROUP BY s.GuidIncidencia
ORDER BY n_sesiones DESC;
