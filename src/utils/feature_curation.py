"""
Curación conceptual de variables ANTES del filtrado estadístico (VIF / correlación).

PROBLEMA METODOLÓGICO
---------------------
El filtrado por VIF (Variance Inflation Factor) elimina variables muy correlacionadas
entre sí. Como TODAS las medidas de rendimiento académico (nota media, notas por materia,
notas por bloque, nº de suspensos) están fuertemente intercorrelacionadas, un VIF ciego
las elimina casi en bloque y deja el modelo sin las variables que la teoría señala como
las MÁS predictivas. El modelo resultante "predice sin mirar las notas", lo cual carece
de sentido pedagógico.

FUNDAMENTO TEÓRICO (por qué el rendimiento previo NO puede eliminarse)
---------------------------------------------------------------------
El rendimiento académico previo es, de forma robusta, el predictor más fuerte del
rendimiento futuro:
  - Hattie, J. (2009). *Visible Learning*. Routledge. — el rendimiento previo presenta
    de los mayores tamaños de efecto sobre el logro posterior.
  - Richardson, M., Abraham, C., & Bond, R. (2012). "Psychological correlates of university
    students' academic performance: A systematic review and meta-analysis." *Psychological
    Bulletin*, 138(2). — las calificaciones previas son el correlato más potente del GPA.
  - Hellas, A. et al. (2018). "Predicting academic performance: A systematic literature
    review." *ITiCSE*. — el desempeño académico previo es la variable más utilizada y más
    predictiva en la minería de datos educativa.
  - Credé, M., Roch, S. G., & Kieszczynka, U. M. (2010). "Class attendance in college: A
    meta-analytic review." *Review of Educational Research*, 80(2). — la asistencia predice
    de forma consistente las calificaciones (justifica proteger la asistencia).

PITFALL DEL VIF Y JUSTIFICACIÓN DE LA CURACIÓN
----------------------------------------------
  - Dormann, C. F. et al. (2013). "Collinearity: a review of methods to deal with it."
    *Ecography*, 36(1). — recomiendan NO eliminar variables solo por colinealidad estadística;
    el conocimiento del dominio debe guiar qué se retiene.
  - Strobl, C. et al. (2008). "Conditional variable importance for random forests."
    *BMC Bioinformatics*, 9:307. — en modelos de árboles la multicolinealidad NO degrada la
    predicción, por lo que el conjunto completo es válido para XGBoost.

ESTRATEGIA
----------
1. Eliminar variables CONCEPTUALMENTE REDUNDANTES (derivadas/duplicadas), no por estadística.
2. Marcar como PROTEGIDAS las variables teóricamente nucleares (rendimiento global, por área,
   materias troncales, repetidor/NEE, asistencia): el VIF NUNCA puede eliminarlas.
3. El VIF se aplica solo al resto, para podar redundancia residual.
"""

# ── Variables PROTEGIDAS — núcleo teórico, el VIF no puede eliminarlas ─────────
PROTEGIDAS = {
    # Rendimiento global 1EV (predictor dominante)
    'nota_media_1ev', 'nota_min_1ev', 'n_suspensos_1ev', 'pct_aprobado_1ev',
    # Rendimiento por ÁREA competencial (explicabilidad por bloque)
    'nota_media__LING', 'nota_media__STEM', 'nota_media__SOC', 'nota_media__PERS',
    # Materias troncales (explicabilidad por asignatura)
    'mat__Matematicas', 'mat__Lengua_Castellana', 'mat__Lengua_Catalana', 'mat__Ingles',
    # Factores de riesgo establecidos en la literatura
    'IsRepetidor', 'tiene_NEE',
    # Asistencia (predictor meta-analítico)
    'total_incidencias_1ev_log', 'no_justificadas_1ev_log',
}

# ── Variables CONCEPTUALMENTE REDUNDANTES — se quitan antes del VIF ────────────
# (derivadas o duplicadas; su información ya está en otra variable retenida)
REDUNDANTES_CONCEPTUALES = {
    'nota_max_1ev',           # techo: poco informativo del riesgo frente a media/mínimo
    'n_aprobadas_1ev',        # = n_asignaturas_1ev - n_suspensos_1ev (redundante)
    'justificadas_1ev_log',   # faltas justificadas: menor valor predictivo que las no justificadas
    'tiene_faltas_total',     # redundante con total_incidencias_1ev_log
    # min/max por bloque: redundantes con la media y el % aprobado del bloque
    'nota_min__LING', 'nota_min__STEM', 'nota_min__SOC', 'nota_min__PERS',
    'nota_max__LING', 'nota_max__STEM', 'nota_max__SOC', 'nota_max__PERS',
}


def curar_features(feat_cols):
    """Aplica la curación conceptual.

    Devuelve (curadas, protegidas_presentes):
      - curadas: feat_cols sin las redundantes conceptuales.
      - protegidas_presentes: subconjunto de PROTEGIDAS presente en los datos
        (el VIF no debe eliminarlas).
    """
    curadas = [c for c in feat_cols if c not in REDUNDANTES_CONCEPTUALES]
    protegidas = [c for c in curadas if c in PROTEGIDAS]
    return curadas, protegidas
