-- =============================================================================
-- Q_V4_FIX_SCHEMA: Columnas de NivGrupo, NivCurso y NivEstudio
-- =============================================================================
-- Ejecutar esto ANTES de corregir Q_v4_01/03.
-- Necesitamos los nombres exactos de los campos de FK entre estas tablas.
-- =============================================================================

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('NivGrupo', 'NivCurso', 'NivEstudio')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
