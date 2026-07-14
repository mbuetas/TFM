-- ============================================================================
-- QDIAG_08 — Barrido: ¿hay notas de 1EV de 2025 en OTRAS tablas?
-- ============================================================================
-- Contexto: en EvaExpedienteNota (boletín) y EvaObjetivoNota (criterios) las
-- notas de 1EV de 2025 cubren solo ~1-2 asignaturas/alumno. Si el dato de las
-- 12-13 asignaturas existe, está en otra tabla. Este barrido tiene 2 pasos:
--   PARTE A: ubicar columnas de las tablas candidatas (reconocimiento).
--   PARTE B: medir el "grado de relleno" real de la 1EV en EEN (celdas
--            alumno×asignatura posibles vs. con nota), para cuantificar el hueco.
-- Con la PARTE A escribo el barrido preciso (QDIAG_09) sobre las que tengan dato.
-- ============================================================================

-- ── PARTE A: columnas de las tablas de notas candidatas ──────────────────────
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN (
    'EvaNotaDiaria',            -- notas/controles diarios (cabecera)
    'EvaNotaDiariaNota',        -- nota diaria por alumno (6.454 filas)
    'EvaNotaDiariaObjetivo',    -- nota diaria por criterio
    'EvaAspectoNota',           -- competencias clave (Tipo='B')
    'EvaAspectoEvaluacion',
    'EvaExpedienteAcumulado',   -- acumulados por expediente
    'EvaExpedienteNotaMedia',   -- medias calculadas por expediente
    'EvaExpedienteMediaCategoriaEstandares',
    'EvaGradoDesarrolloNota',   -- grado de desarrollo (Infantil/competencial)
    'EvaSubControlNota',        -- subcontroles (parciales dentro de un control)
    'EvaCalificacionProfesional'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ── PARTE B: grado de relleno de la 1EV en EEN (boletín), 2025 ──────────────
-- celdas_posibles  = expedientes (alumno × asignatura matriculada) de 2025
-- celdas_con_nota  = cuántas de esas tienen nota de 1EV (Tipo='E',Numero=1)
-- Un % bajo confirma que la 1EV no se cargó por asignatura.
WITH expedientes_2025 AS (
    SELECT
        e.Guid          AS GuidExpediente,
        m.GuidAlumno,
        ne.Nombre_Lng1  AS NivEstudio
    FROM dbo.EvaExpediente e
    JOIN dbo.EvaOferta     o   ON o.Guid = e.GuidOferta AND o.Ejercicio = 2025 AND o.IsEvaluable = 1
    JOIN dbo.Matricula     m   ON m.Guid = e.GuidMatricula AND m.IsMatriculaPrincipal = 1
    JOIN dbo.NivGrupo      ng  ON ng.Guid = m.GuidGrupo
    JOIN dbo.NivEstudio    ne  ON ne.Guid = ng.GuidEstudio
    WHERE e.NoMatriculado = 0
      AND ne.Nombre_Lng1 IN ('Bachillerato', 'Educación Primaria')
),
con_nota_1ev AS (
    SELECT DISTINCT en.GuidExpediente
    FROM dbo.EvaExpedienteNota en
    JOIN dbo.EvaEvaluacion ev ON ev.Guid = en.GuidEvaluacion
                             AND ev.Tipo='E' AND ev.Numero=1 AND ev.Estado='A'
)
SELECT
    x.NivEstudio,
    COUNT(DISTINCT x.GuidAlumno)                                          AS n_alumnos,
    COUNT(*)                                                              AS celdas_posibles,
    SUM(CASE WHEN c.GuidExpediente IS NOT NULL THEN 1 ELSE 0 END)         AS celdas_con_nota_1ev,
    CAST(100.0 * SUM(CASE WHEN c.GuidExpediente IS NOT NULL THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*),0) AS DECIMAL(5,1))                            AS pct_relleno
FROM expedientes_2025 x
LEFT JOIN con_nota_1ev c ON c.GuidExpediente = x.GuidExpediente
GROUP BY x.NivEstudio;
