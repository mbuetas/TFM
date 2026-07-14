"""
Métrica custom para predicción de rendimiento académico.

Clases: 0=buen_alumno, 1=en_riesgo, 2=con_dificultades

Lógica de costos (pedido por el usuario):
  - Predecir "buen" cuando es "con_dificultades" → costo MÁS ALTO (no detectar al que recusará)
  - Predecir "buen" cuando es "en_riesgo"        → costo ALTO (no detectar alumno en riesgo)
  - Predecir "con_dif" cuando es "en_riesgo"     → costo BAJO (alarma conservadora, aceptable)
  - Errores en buen_alumno: sobre-cautela, coste moderado
"""

import numpy as np
from sklearn.metrics import make_scorer

# Matriz de costos — rows=actual, cols=predicho
# Eje 0 (filas): clase real | Eje 1 (columnas): clase predicha
# buen=0, en_riesgo=1, con_dificultades=2
# V11 (ajuste del usuario): se REFUERZA el castigo a NO detectar el riesgo —
# predecir "buen" cuando el alumno está en_riesgo (3→4) o con_dificultades (5→8).
# Prioriza la sensibilidad (recall) sobre los alumnos que van mal.
COST_MATRIX = np.array([
    [0, 1, 2],   # actual buen_alumno:      predecir en_riesgo (1) o con_dif (2) = sobre-cautela
    [4, 0, 1],   # actual en_riesgo:        predecir buen (4) >> predecir con_dif (1)
    [8, 2, 0],   # actual con_dificultades: predecir buen (8) máximo | predecir en_riesgo (2)
], dtype=float)

MAX_COST = COST_MATRIX.max()           # 5.0
WORST_MEAN_COST = COST_MATRIX.mean()   # costo si se predice aleatoriamente (aprox.)

CAT_ORDER = ['buen_alumno', 'en_riesgo', 'con_dificultades']


def costo_medio(y_true, y_pred):
    """
    Costo medio según COST_MATRIX.
    Menor es mejor (0 = predicción perfecta, 5 = peor error posible).
    """
    y_true = np.asarray(y_true, dtype=int)
    y_pred = np.asarray(y_pred, dtype=int)
    return float(COST_MATRIX[y_true, y_pred].mean())


def score_academico(y_true, y_pred):
    """
    Score académico costo-sensible: 1.0 = perfecto, 0.0 = peor posible.
    Compatible con sklearn.metrics.make_scorer (greater_is_better=True).

    Interpretación:
        1.0  → ningún error
        0.8+ → muy buen rendimiento
        0.6  → nivel aleatorio inteligente
        < 0.6 → peor que un clasificador ingenuo
    """
    y_true = np.asarray(y_true, dtype=int)
    y_pred = np.asarray(y_pred, dtype=int)
    cost = COST_MATRIX[y_true, y_pred].mean()
    return float(1.0 - cost / MAX_COST)


def matriz_costos_df():
    """Devuelve la matriz de costos como DataFrame para visualización."""
    import pandas as pd
    return pd.DataFrame(COST_MATRIX, index=CAT_ORDER, columns=CAT_ORDER)


def reporte_costos(y_true, y_pred):
    """
    Reporte detallado: costo por celda, costo total, score académico.
    """
    y_true = np.asarray(y_true, dtype=int)
    y_pred = np.asarray(y_pred, dtype=int)

    n = len(y_true)
    lines = ["=== Reporte de Costos Académicos ==="]
    lines.append(f"Muestras: {n}")
    lines.append(f"Costo medio: {costo_medio(y_true, y_pred):.3f} / {MAX_COST:.0f}")
    lines.append(f"Score académico: {score_academico(y_true, y_pred):.4f}")
    lines.append("")
    lines.append("Distribución de errores por costo:")

    for cost_val in sorted(set(COST_MATRIX.flatten()) - {0}):
        mask_true, mask_pred = np.where(COST_MATRIX == cost_val)
        for r, c in zip(mask_true, mask_pred):
            count = int(((y_true == r) & (y_pred == c)).sum())
            if count > 0:
                lines.append(
                    f"  costo={cost_val:.0f}: real={CAT_ORDER[r]:<20} "
                    f"pred={CAT_ORDER[c]:<20} → {count}/{n} ({count/n:.1%})"
                )
    return "\n".join(lines)


# Scorer para sklearn.model_selection (GridSearchCV, cross_val_score)
scorer_academico = make_scorer(score_academico, greater_is_better=True)
