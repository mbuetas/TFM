-- ============================================================================
-- QDIAG_19 — ¿Están los datos LOMLOE (2021+) en OTRA base de datos del servidor?
-- ============================================================================
-- Intuición: LOMLOE entra ~2021 y desde ahí "desaparecen" los datos. Es muy
-- posible que los años nuevos se hayan migrado a otra BD del mismo servidor
-- (p.ej. NewSys2050, una BD por reforma, o una BD de otro centro).
-- ============================================================================

-- ── PARTE A: todas las bases de datos del servidor ──────────────────────────
SELECT name, database_id, create_date
FROM sys.databases
ORDER BY name;

-- ── PARTE B: ¿qué bases de datos tienen tablas 'Eva%' (otro ERP de evaluación)?
-- Recorre cada BD accesible y cuenta tablas Eva*. Si otra BD tiene EvaExpedienteNota,
-- ahí pueden estar los años que nos faltan.
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql +
    'SELECT ''' + name + ''' AS base_datos, COUNT(*) AS n_tablas_eva FROM [' + name + '].sys.tables WHERE name LIKE ''Eva%'' UNION ALL '
FROM sys.databases
WHERE state_desc = 'ONLINE'
  AND name NOT IN ('master', 'tempdb', 'model', 'msdb');

SET @sql = LEFT(@sql, LEN(@sql) - LEN(' UNION ALL ')) + ' ORDER BY n_tablas_eva DESC';
EXEC sp_executesql @sql;

-- ── PARTE C: ¿hay ejercicios > 2020 con notas en EvaExpedienteNota (esta BD)? ─
-- Confirma desde qué año exacto se cortan los datos en la BD actual.
SELECT
    o.Ejercicio,
    COUNT(DISTINCT en.GuidExpediente) AS n_expedientes_con_nota,
    COUNT(*)                          AS n_notas
FROM dbo.EvaExpedienteNota en
JOIN dbo.EvaExpediente e ON e.Guid = en.GuidExpediente
JOIN dbo.EvaOferta     o ON o.Guid = e.GuidOferta
GROUP BY o.Ejercicio
ORDER BY o.Ejercicio;
