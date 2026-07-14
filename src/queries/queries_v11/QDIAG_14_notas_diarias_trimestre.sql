-- ============================================================================
-- QDIAG_14 — Notas de clase (EvaNotaDiaria) en la ventana del 1er trimestre
-- ============================================================================
-- Objetivo: evaluar la fuente más inclusiva — las notas de clase/controles —
-- para reconstruir una "nota temprana" por asignatura cuando no hay boletín 1EV.
-- Ventana 1er trimestre = sep–dic del año de inicio del curso (Ejercicio).
--   (Ejercicio=2025 → curso 2025/26 → sep-dic 2025)
-- Define la jerarquía: examen escrito > práctica/proyecto > tarea/deberes.
--
-- TipoEvaluacion (tinyint) + GuidTipoEvaluacion clasifican cada control.
-- Nombre_Lng1 es el nombre que el profe dio al control ("Examen T1", "Deberes").
-- ============================================================================

-- ── PARTE A: ¿hay tabla lookup para el tipo de evaluación de la nota diaria? ─
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%TipoEvaluacion%'
   OR TABLE_NAME LIKE '%TipoNota%'
   OR TABLE_NAME LIKE '%NotaDiariaTipo%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ── PARTE B: cobertura de notas de clase por año y tipo (ventana sep–dic) ────
-- n_asignaturas alto ⇒ esta fuente recupera muchas materias de 1er trimestre.
SELECT
    o.Ejercicio,
    nd.TipoEvaluacion,
    COUNT(DISTINCT o.Guid)              AS n_asignaturas,
    COUNT(DISTINCT m.GuidAlumno)        AS n_alumnos,
    COUNT(DISTINCT nd.Guid)             AS n_controles,
    COUNT(*)                            AS n_notas
FROM dbo.EvaNotaDiariaNota ndn
JOIN dbo.EvaNotaDiaria  nd  ON nd.Guid = ndn.GuidNotaDiaria
JOIN dbo.EvaExpediente  e   ON e.Guid  = ndn.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2018
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
  AND YEAR(nd.Fecha) = o.Ejercicio
  AND MONTH(nd.Fecha) BETWEEN 9 AND 12
GROUP BY o.Ejercicio, nd.TipoEvaluacion
ORDER BY o.Ejercicio, nd.TipoEvaluacion;

-- ── PARTE C: nombres de controles por tipo (muestra) para definir la jerarquía
SELECT TOP 60
    nd.TipoEvaluacion,
    nd.Nombre_Lng1                      AS NombreControl,
    COUNT(*)                            AS n_notas
FROM dbo.EvaNotaDiaria  nd
JOIN dbo.EvaNotaDiariaNota ndn ON ndn.GuidNotaDiaria = nd.Guid
JOIN dbo.EvaExpediente  e   ON e.Guid  = ndn.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio >= 2018
WHERE YEAR(nd.Fecha) BETWEEN 2018 AND 2025
  AND MONTH(nd.Fecha) BETWEEN 9 AND 12
GROUP BY nd.TipoEvaluacion, nd.Nombre_Lng1
ORDER BY n_notas DESC;
