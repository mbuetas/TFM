-- =============================================================================
-- Q_V4_04: Asistencia acumulada en la 1ª evaluación
-- =============================================================================
-- Usa IncIncidenciaSesion con join de fecha a EvaEvaluacion (Tipo=E, Numero=1).
-- IncIncidenciaAcumulado no tiene datos para ejercicios > 2016 — no se usa.
--
-- No filtra por alumnos_validos: devuelve TODOS los alumnos con incidencias
-- en 1EV, independientemente de si tienen nota final. El join con el target
-- se hace en Python (left join; alumnos sin faltas quedan con 0).
--
-- Resultado: una fila por alumno-año.
-- Columnas: GuidAlumno, Ejercicio, IdCentro,
--           total_incidencias_1ev, no_justificadas_1ev, justificadas_1ev
-- =============================================================================

SELECT
    m.GuidAlumno,
    o.Ejercicio,
    m.IdCentro,
    COUNT(*)                                                AS total_incidencias_1ev,
    SUM(CASE WHEN ii.EsJustificada = 0 THEN 1 ELSE 0 END)  AS no_justificadas_1ev,
    SUM(CASE WHEN ii.EsJustificada = 1 THEN 1 ELSE 0 END)  AS justificadas_1ev
FROM dbo.IncIncidenciaSesion inc
JOIN dbo.IncIncidencia      ii  ON ii.Guid  = inc.GuidIncidencia
JOIN dbo.Matricula          m   ON m.Guid   = inc.GuidMatricula
JOIN dbo.EvaOferta          o   ON o.Guid   = inc.GuidOferta
JOIN dbo.EvaEvaluacion      ev  ON inc.Fecha BETWEEN ev.FechaInicio AND ev.FechaFinal
                                AND ev.Estado = 'A'
                                AND ev.Tipo   = 'E'
                                AND ev.Numero = 1
WHERE m.IsMatriculaPrincipal = 1
  AND o.IsEvaluable          = 1
GROUP BY m.GuidAlumno, o.Ejercicio, m.IdCentro
ORDER BY o.Ejercicio DESC, total_incidencias_1ev DESC;
