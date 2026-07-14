-- ============================================================================
-- QDIAG_12 — ¿Dónde están las notas de 2023 y 2024? (están oscuras en QDIAG_11)
-- ============================================================================
-- En QDIAG_11 los años 2023/2024 no aparecen en ninguna tabla, pese a tener
-- 362 y 293 alumnos matriculados. Dos hipótesis:
--   (1) sus notas están en otra tabla de notas no contemplada, o
--   (2) un filtro las tira (IsMatriculaPrincipal=1 / NoMatriculado=0).
-- Este barrido cuenta notas SIN filtros de matrícula, ligando solo por
-- expediente→oferta(Ejercicio IN 2023,2024). Si aparecen, el filtro era el culpable.
-- ============================================================================

-- ── PARTE A: notas por tabla para 2023/2024, SIN filtros de matrícula ────────
SELECT 'EvaExpedienteNota' AS fuente, o.Ejercicio,
       COUNT(DISTINCT e.Guid) AS n_expedientes, COUNT(*) AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaExpediente e ON e.Guid = en.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaObjetivoNota', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaObjetivoNota eon
JOIN dbo.EvaExpediente e ON e.Guid = eon.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaAspectoNota', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaExpediente e ON e.Guid = an.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaExpedienteNotaMedia', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaExpediente e ON e.Guid = em.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaNotaDiariaNota', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaNotaDiariaNota ndn
JOIN dbo.EvaExpediente e ON e.Guid = ndn.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaSubControlNota', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaSubControlNota sc
JOIN dbo.EvaExpediente e ON e.Guid = sc.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaGradoDesarrolloNota', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaGradoDesarrolloNota gd
JOIN dbo.EvaExpediente e ON e.Guid = gd.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

UNION ALL
SELECT 'EvaExpedienteMediaCategoriaEstandares', o.Ejercicio, COUNT(DISTINCT e.Guid), COUNT(*)
FROM dbo.EvaExpedienteMediaCategoriaEstandares mc
JOIN dbo.EvaExpediente e ON e.Guid = mc.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio

ORDER BY fuente, Ejercicio;

-- ── PARTE B: si EEN tiene notas en 2023/2024, ¿bajo qué Tipo/Numero/Estado? ──
-- Revela el calendario de evaluación real de esos años (quizá 1EV/final usan
-- numeración distinta y por eso QDIAG_11 los clasificó como vacíos).
SELECT o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado,
       COUNT(DISTINCT e.Guid) AS n_expedientes, COUNT(*) AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaEvaluacion ev ON ev.Guid = en.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = en.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.Ejercicio IN (2023, 2024)
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero, ev.Estado
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;
