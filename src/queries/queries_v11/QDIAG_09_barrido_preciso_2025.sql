-- ============================================================================
-- QDIAG_09 — Barrido preciso: ¿alguna tabla tiene las ~13 asignaturas de 1EV 2025?
-- ============================================================================
-- Para cada tabla de notas candidata cuenta, en 2025 Bach + Primaria:
--   n_alumnos, n_asignaturas (DISTINCT oferta), n_notas.
-- CLAVE: si n_asignaturas ≈ 13 (Bach) en alguna tabla → ahí están las notas de
-- 1EV de todas las materias y 2025 se puede modelar. Si todas dan ~1 (solo
-- Lengua), queda probado que el dato no existe.
--
-- Filtro 1EV: por período Tipo='E',Numero=1 donde la tabla tiene GuidEvaluacion;
-- por ventana de fechas (sep–dic 2025) en las notas diarias.
-- ============================================================================

-- EvaNotaDiariaNota — notas/controles diarios en la ventana de 1EV (sep–dic 2025)
SELECT 'EvaNotaDiariaNota' AS tabla, ne.Nombre_Lng1 AS NivEstudio,
       COUNT(DISTINCT m.GuidAlumno) AS n_alumnos,
       COUNT(DISTINCT o.Guid)       AS n_asignaturas,
       COUNT(*)                     AS n_notas
FROM dbo.EvaNotaDiariaNota ndn
JOIN dbo.EvaNotaDiaria     nd  ON nd.Guid = ndn.GuidNotaDiaria
JOIN dbo.EvaExpediente     e   ON e.Guid  = ndn.GuidExpediente
JOIN dbo.EvaOferta         o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula         m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo          ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio        ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
  AND nd.Fecha >= '20250901' AND nd.Fecha < '20251220'
GROUP BY ne.Nombre_Lng1

UNION ALL
-- EvaAspectoNota — competencias clave, período 1EV
SELECT 'EvaAspectoNota', ne.Nombre_Lng1,
       COUNT(DISTINCT m.GuidAlumno), COUNT(DISTINCT o.Guid), COUNT(*)
FROM dbo.EvaAspectoNota an
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = an.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = an.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1

UNION ALL
-- EvaGradoDesarrolloNota — grado de desarrollo competencial, período 1EV
SELECT 'EvaGradoDesarrolloNota', ne.Nombre_Lng1,
       COUNT(DISTINCT m.GuidAlumno), COUNT(DISTINCT o.Guid), COUNT(*)
FROM dbo.EvaGradoDesarrolloNota gd
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = gd.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = gd.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1

UNION ALL
-- EvaSubControlNota — subcontroles/parciales (sin GuidEvaluacion → todo 2025)
SELECT 'EvaSubControlNota (todo 2025)', ne.Nombre_Lng1,
       COUNT(DISTINCT m.GuidAlumno), COUNT(DISTINCT o.Guid), COUNT(*)
FROM dbo.EvaSubControlNota sc
JOIN dbo.EvaExpediente  e   ON e.Guid  = sc.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1

UNION ALL
-- EvaExpedienteNotaMedia — medias calculadas, período 1EV
SELECT 'EvaExpedienteNotaMedia', ne.Nombre_Lng1,
       COUNT(DISTINCT m.GuidAlumno), COUNT(DISTINCT o.Guid), COUNT(*)
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaEvaluacion  ev  ON ev.Guid = em.GuidEvaluacion
                            AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
JOIN dbo.EvaExpediente  e   ON e.Guid  = em.GuidExpediente
JOIN dbo.EvaOferta      o   ON o.Guid  = e.GuidOferta AND o.Ejercicio = 2025
JOIN dbo.Matricula      m   ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
JOIN dbo.NivGrupo       ng  ON ng.Guid = m.GuidGrupo
JOIN dbo.NivEstudio     ne  ON ne.Guid = ng.GuidEstudio
WHERE ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
GROUP BY ne.Nombre_Lng1

ORDER BY tabla, NivEstudio;
