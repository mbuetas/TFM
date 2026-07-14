-- ============================================================================
-- QDIAG_06 — Calendario de evaluaciones 2025 por nivel (EON y EEN)
-- ============================================================================
-- Motivo: QDIAG_04c reveló que en 2025 hay DOS períodos Tipo='E',Numero=1:
--   · 08-sep → 07-dic  (~90 días)  = 1er TRIMESTRE real (Bachillerato)
--   · 12-sep → 18-sep  (6 días)    = evaluación INICIAL/diagnóstica (Primaria)
-- Ambos pasan el filtro Tipo='E',Numero=1,Estado='A', así que Q01b mezclaría
-- el trimestre de Bach con la inicial de Primaria.
--
-- Objetivo: listar TODOS los períodos de evaluación usados en 2025, por nivel,
-- con su duración, para identificar cuál es el 1er trimestre real de cada nivel
-- y si Primaria tiene (o no) un trimestre real en EON aparte de la inicial.
-- ============================================================================

-- ── PARTE A: períodos referenciados por EON (criterios LOMLOE), por nivel ────
SELECT
    'EON' AS fuente,
    ne.Nombre_Lng1                                       AS NivEstudio,
    ev.Tipo,
    ev.Numero,
    ev.Estado,
    ev.FechaInicio,
    ev.FechaFinal,
    DATEDIFF(DAY, ev.FechaInicio, ev.FechaFinal)         AS dias_duracion,
    COUNT(DISTINCT o.Guid)                               AS n_ofertas,
    COUNT(DISTINCT m.GuidAlumno)                         AS n_alumnos,
    COUNT(*)                                             AS n_notas
FROM dbo.EvaObjetivoNota        eon
JOIN dbo.EvaObjetivo_Evaluacion oev ON oev.Guid = eon.GuidObjetivo_Evaluacion
JOIN dbo.EvaObjetivo            ob  ON ob.Guid  = oev.GuidObjetivo
JOIN dbo.EvaEvaluacion          ev  ON ev.Guid  = oev.GuidEvaluacion
JOIN dbo.EvaOferta              o   ON o.Guid   = ob.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.EvaExpediente          e   ON e.Guid   = eon.GuidExpediente AND e.GuidOferta = o.Guid
JOIN dbo.Matricula              m   ON m.Guid   = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo               ng  ON ng.Guid  = m.GuidGrupo
JOIN dbo.NivEstudio             ne  ON ne.Guid  = ng.GuidEstudio
GROUP BY ne.Nombre_Lng1, ev.Tipo, ev.Numero, ev.Estado, ev.FechaInicio, ev.FechaFinal
ORDER BY ne.Nombre_Lng1, ev.FechaInicio;

-- ── PARTE B: períodos referenciados por EEN (boletín), por nivel ────────────
SELECT
    'EEN' AS fuente,
    ne.Nombre_Lng1                                       AS NivEstudio,
    ev.Tipo,
    ev.Numero,
    ev.Estado,
    ev.FechaInicio,
    ev.FechaFinal,
    DATEDIFF(DAY, ev.FechaInicio, ev.FechaFinal)         AS dias_duracion,
    COUNT(DISTINCT o.Guid)                               AS n_ofertas,
    COUNT(DISTINCT m.GuidAlumno)                         AS n_alumnos,
    COUNT(*)                                             AS n_notas
FROM dbo.EvaExpedienteNota  en
JOIN dbo.EvaEvaluacion      ev  ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente      e   ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta          o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula          m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo           ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio         ne  ON ne.Guid = ng.GuidEstudio
GROUP BY ne.Nombre_Lng1, ev.Tipo, ev.Numero, ev.Estado, ev.FechaInicio, ev.FechaFinal
ORDER BY ne.Nombre_Lng1, ev.FechaInicio;
