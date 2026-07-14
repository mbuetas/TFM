-- ============================================================================
-- QDIAG_15 — Re-minado: notas guardadas como TEXTO (CÓDIGO_NÚMERO)
-- ============================================================================
-- Hallazgo: EvaExpedienteNotaMedia.Valor guarda notas como 'B_7.00', 'N+_8.00',
-- 'S_5.33'... El número tras el '_' es la nota; el prefijo es el código cualitativo.
-- ISNUMERIC las descartó por el prefijo → subestimamos la cobertura.
--
-- Aquí extraigo el número (parte tras el último '_', o el valor entero si es
-- número plano) y mido la cobertura real por (año, período).
-- También re-examino EvaExpedienteMediaCategoriaEstandares (Valor/Numerico texto).
-- ============================================================================

-- ── PARTE A: muestra del parseo (crudo → número) para verificar la lógica ───
SELECT TOP 50
    em.Valor                                                AS valor_crudo,
    LTRIM(RTRIM(
        CASE WHEN CHARINDEX('_', em.Valor) > 0
             THEN SUBSTRING(em.Valor, CHARINDEX('_', em.Valor) + 1, 50)
             ELSE em.Valor END
    ))                                                      AS valor_parseado,
    COUNT(*)                                                AS n
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaExpediente e ON e.Guid = em.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio >= 2018
WHERE em.Valor IS NOT NULL AND LTRIM(RTRIM(em.Valor)) <> ''
GROUP BY em.Valor
ORDER BY n DESC;

-- ── PARTE B: NotaMedia — cobertura REAL parseada por (año, Tipo, Numero) ─────
-- n_asignaturas alto en E/1 ⇒ recuperamos las features de 1EV de ese año.
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero,
    COUNT(*)                                                AS n_celdas,
    SUM(CASE WHEN ISNUMERIC(LTRIM(RTRIM(
        CASE WHEN CHARINDEX('_', em.Valor) > 0
             THEN SUBSTRING(em.Valor, CHARINDEX('_', em.Valor) + 1, 50)
             ELSE em.Valor END))) = 1 THEN 1 ELSE 0 END)    AS n_con_nota,
    COUNT(DISTINCT CASE WHEN ISNUMERIC(LTRIM(RTRIM(
        CASE WHEN CHARINDEX('_', em.Valor) > 0
             THEN SUBSTRING(em.Valor, CHARINDEX('_', em.Valor) + 1, 50)
             ELSE em.Valor END))) = 1 THEN m.GuidAlumno END) AS n_alumnos,
    COUNT(DISTINCT CASE WHEN ISNUMERIC(LTRIM(RTRIM(
        CASE WHEN CHARINDEX('_', em.Valor) > 0
             THEN SUBSTRING(em.Valor, CHARINDEX('_', em.Valor) + 1, 50)
             ELSE em.Valor END))) = 1 THEN e.GuidOferta END) AS n_asignaturas
FROM dbo.EvaExpedienteNotaMedia em
JOIN dbo.EvaEvaluacion ev ON ev.Guid = em.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = em.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2018
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;

-- ── PARTE C: MediaCategoriaEstandares — ¿tiene notas (texto) por asignatura? ─
-- Muestra de valores
SELECT TOP 30 mc.Categoria, mc.Valor, mc.Codigo, mc.Numerico, COUNT(*) AS n
FROM dbo.EvaExpedienteMediaCategoriaEstandares mc
JOIN dbo.EvaExpediente e ON e.Guid = mc.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta AND o.Ejercicio >= 2018
GROUP BY mc.Categoria, mc.Valor, mc.Codigo, mc.Numerico
ORDER BY n DESC;

-- Cobertura por (año, Tipo, Numero) usando Numerico
SELECT
    o.Ejercicio, ev.Tipo, ev.Numero,
    COUNT(*)                                                          AS n_celdas,
    SUM(CASE WHEN ISNUMERIC(mc.Numerico) = 1 THEN 1 ELSE 0 END)       AS n_con_nota,
    COUNT(DISTINCT CASE WHEN ISNUMERIC(mc.Numerico) = 1 THEN m.GuidAlumno END)  AS n_alumnos,
    COUNT(DISTINCT CASE WHEN ISNUMERIC(mc.Numerico) = 1 THEN e.GuidOferta END)  AS n_asignaturas
FROM dbo.EvaExpedienteMediaCategoriaEstandares mc
JOIN dbo.EvaEvaluacion ev ON ev.Guid = mc.GuidEvaluacion
JOIN dbo.EvaExpediente e  ON e.Guid  = mc.GuidExpediente
JOIN dbo.EvaOferta     o  ON o.Guid  = e.GuidOferta AND o.IsEvaluable = 1 AND o.Ejercicio >= 2018
JOIN dbo.Matricula     m  ON m.Guid  = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
WHERE e.NoMatriculado = 0
GROUP BY o.Ejercicio, ev.Tipo, ev.Numero
ORDER BY o.Ejercicio, ev.Tipo, ev.Numero;
