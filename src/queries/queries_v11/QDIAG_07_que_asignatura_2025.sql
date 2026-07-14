-- ============================================================================
-- QDIAG_07 — ¿Qué asignatura(s) de 1EV existen en 2025 y dónde? (Bach + Primaria)
-- ============================================================================
-- Responde 3 preguntas antes de decidir qué hacer con 2025:
--   A) ¿Cuál es la(s) asignatura(s) con criterios EON en 1EV? ¿La misma para todos?
--   B) ¿Cuántos alumnos tienen nota de 1EV por asignatura en EEN (boletín)?
--   C) ¿Existe la nota de 1EV en otra tabla (EvaExpedienteNotaMedia)?
-- ============================================================================

-- ── PARTE A: asignatura(s) con criterios EON en 1EV, por nombre ──────────────
SELECT
    ne.Nombre_Lng1                                          AS NivEstudio,
    o.CodigoOficial                                         AS CodigoAsignatura,
    o.Nombre_Lng1                                           AS Asignatura,
    COUNT(DISTINCT m.GuidAlumno)                            AS n_alumnos,
    COUNT(DISTINCT ob.Guid)                                 AS n_criterios_distintos,
    COUNT(*)                                                AS n_notas_criterio
FROM dbo.EvaObjetivoNota        eon
JOIN dbo.EvaObjetivo_Evaluacion oev ON oev.Guid = eon.GuidObjetivo_Evaluacion
JOIN dbo.EvaObjetivo            ob  ON ob.Guid  = oev.GuidObjetivo
JOIN dbo.EvaEvaluacion          ev  ON ev.Guid  = oev.GuidEvaluacion
                                    AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaOferta              o   ON o.Guid   = ob.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.EvaExpediente          e   ON e.Guid   = eon.GuidExpediente AND e.GuidOferta = o.Guid
JOIN dbo.Matricula              m   ON m.Guid   = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo               ng  ON ng.Guid  = m.GuidGrupo
JOIN dbo.NivEstudio             ne  ON ne.Guid  = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1, o.CodigoOficial, o.Nombre_Lng1
ORDER BY ne.Nombre_Lng1, n_alumnos DESC;

-- ── PARTE B: cobertura de 1EV en EEN (boletín) por asignatura ────────────────
-- Lista TODAS las asignaturas y cuántos alumnos tienen nota de 1EV en cada una.
-- Esperado si el dato no existe: casi todas con 0-2 alumnos.
SELECT
    ne.Nombre_Lng1                                          AS NivEstudio,
    o.CodigoOficial                                         AS CodigoAsignatura,
    o.Nombre_Lng1                                           AS Asignatura,
    COUNT(DISTINCT m.GuidAlumno)                            AS n_alumnos_con_nota_1ev
FROM dbo.EvaExpedienteNota  en
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = en.GuidEvaluacion
                                AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente      e   ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta          o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula          m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo           ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio         ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1, o.CodigoOficial, o.Nombre_Lng1
ORDER BY ne.Nombre_Lng1, n_alumnos_con_nota_1ev DESC;

-- ── PARTE C: ¿hay nota de 1EV en EvaExpedienteNotaMedia? ─────────────────────
-- Primero el schema (para saber qué columnas tiene), luego un conteo por si las
-- medias de 1EV de 2025 viven aquí en vez de en EvaExpedienteNota.
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EvaExpedienteNotaMedia'
ORDER BY ORDINAL_POSITION;

-- Conteo de filas de EvaExpedienteNotaMedia ligadas a la 1EV de 2025
SELECT
    ne.Nombre_Lng1                                          AS NivEstudio,
    COUNT(DISTINCT m.GuidAlumno)                            AS n_alumnos,
    COUNT(DISTINCT e.GuidOferta)                            AS n_asignaturas,
    COUNT(*)                                                AS n_filas
FROM dbo.EvaExpedienteNotaMedia enm
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = enm.GuidEvaluacion
                                AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente      e   ON e.Guid  = enm.GuidExpediente
JOIN dbo.EvaOferta          o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula          m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo           ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio         ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1;
