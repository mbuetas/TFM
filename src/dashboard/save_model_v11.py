"""
Entrena el modelo V11 (XGBoost) con los hiperparámetros óptimos del NB08_modelado_MB.ipynb
y lo guarda en models/model_v11_xgb.pkl. Ejecutar UNA vez antes de lanzar app.py.

Uso (desde la raíz del proyecto TFM):
    python src/dashboard/save_model_v11.py
"""
import sys
import pickle
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.extend([str(BASE_DIR), str(BASE_DIR / "notebooks")])

import numpy as np
import pandas as pd
from sklearn.pipeline import Pipeline

from src.utils.metrics import scorer_academico, COST_MATRIX
from src.utils.balanced_xgb import BalancedXGB
from preprocessing_pipeline import build_preprocessor

SEED = 42
CAT_ORDER = ["buen_alumno", "en_riesgo", "con_dificultades"]

BEST_PARAMS = dict(
    subsample=0.8,
    reg_lambda=5,
    reg_alpha=0,
    n_estimators=100,
    min_child_weight=5,
    max_depth=2,
    learning_rate=0.08,
    gamma=0.5,
    colsample_bytree=0.5,
)


def main():
    data_path = BASE_DIR / "data" / "dataset_v11_fe.csv"
    print(f"Cargando {data_path.name} …")
    df = pd.read_csv(data_path)
    df["categoria_target"] = pd.Categorical(
        df["categoria_target"], categories=CAT_ORDER, ordered=True
    )

    EXCL = {"target_num", "categoria_target", "GuidAlumno"}
    feat_cols = [c for c in df.columns if c not in EXCL and c != "Ejercicio"]
    X = df[feat_cols].copy()
    y = df["target_num"].values

    print(f"Dataset: {df.shape}  |  Features: {len(feat_cols)}")
    print(f"Target dist: {dict(zip(*np.unique(y, return_counts=True)))}")

    clf = BalancedXGB(
        **BEST_PARAMS,
        eval_metric="mlogloss",
        random_state=SEED,
        n_jobs=-1,
        objective="multi:softprob",
        num_class=3,
    )
    pipe = Pipeline(
        [
            (
                "prep",
                build_preprocessor(
                    X.columns.tolist(),
                    group_col="NivEstudio",
                    nivcurso_col="NivCurso",
                    scale=False,
                    impute=False,
                ),
            ),
            ("clf", clf),
        ]
    )

    print("Entrenando pipeline …")
    pipe.fit(X, y)

    score = scorer_academico(pipe, X, y)
    print(f"score_academico (in-sample): {score:.4f}")

    out = {
        "pipeline": pipe,
        "feature_cols": feat_cols,
        "cat_order": CAT_ORDER,
        "cost_matrix": COST_MATRIX,
        "max_cost": float(COST_MATRIX.max()),
    }
    out_path = BASE_DIR / "models" / "model_v11_xgb.pkl"
    with open(out_path, "wb") as f:
        pickle.dump(out, f)
    print(f"Guardado en: {out_path}")


if __name__ == "__main__":
    main()
