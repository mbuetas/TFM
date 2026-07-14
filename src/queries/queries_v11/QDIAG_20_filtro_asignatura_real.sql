-- ============================================================================
-- QDIAG_20 — Definir el filtro de "asignatura real" (vs observación/IB/sub-área)
-- ============================================================================
-- El alumno de muestra tiene 58 ofertas: ~8 materias reales + observaciones de
-- conducta + unidades IB + sub-áreas. Necesitamos el flag/columna que las separa.
-- Candidatos: CodigoOficial no vacío, GuidOfertaPadre IS NULL, IsCuentaPromedio=1,
-- IsComplementaria=0, TipoAsignacion.
-- ============================================================================

SELECT DISTINCT
    CASE WHEN o.CodigoOficial IS NULL OR LTRIM(RTRIM(o.CodigoOficial)) = ''
         THEN '(sin codigo)' ELSE o.CodigoOficial END        AS codigo,
    o.Nombre_Lng1,
    CASE WHEN o.GuidOfertaPadre IS NULL THEN 'top' ELSE 'hija' END AS jerarquia,
    o.IsCuentaPromedio,
    o.IsComplementaria,
    o.IsOptativa,
    o.TipoAsignacion,
    o.Calculo,
    o.Peso
FROM dbo.Matricula      m
JOIN dbo.EvaExpediente  e ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
JOIN dbo.EvaOferta      o ON o.Guid = e.GuidOferta AND o.Ejercicio = 2020 AND o.IsEvaluable = 1
WHERE m.GuidAlumno = '02A90042-FA44-0C95-E7FE-D5E89580D408'
  AND m.IsMatriculaPrincipal = 1
ORDER BY jerarquia, codigo, o.Nombre_Lng1;

-- ── Conteo de cuántas materias quedan con cada filtro candidato ──────────────
SELECT
    COUNT(DISTINCT e.GuidOferta)                                                      AS total_evaluables,
    COUNT(DISTINCT CASE WHEN o.CodigoOficial IS NOT NULL AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
                        THEN e.GuidOferta END)                                        AS con_codigo,
    COUNT(DISTINCT CASE WHEN o.GuidOfertaPadre IS NULL THEN e.GuidOferta END)         AS solo_top,
    COUNT(DISTINCT CASE WHEN o.IsCuentaPromedio = 1 THEN e.GuidOferta END)            AS cuenta_promedio,
    COUNT(DISTINCT CASE WHEN o.IsCuentaPromedio = 1
                         AND o.CodigoOficial IS NOT NULL AND LTRIM(RTRIM(o.CodigoOficial)) <> ''
                        THEN e.GuidOferta END)                                        AS combo_codigo_y_promedio
FROM dbo.Matricula      m
JOIN dbo.EvaExpediente  e ON e.GuidMatricula = m.Guid AND e.NoMatriculado = 0
JOIN dbo.EvaOferta      o ON o.Guid = e.GuidOferta AND o.Ejercicio = 2020 AND o.IsEvaluable = 1
WHERE m.GuidAlumno = '02A90042-FA44-0C95-E7FE-D5E89580D408'
  AND m.IsMatriculaPrincipal = 1;
