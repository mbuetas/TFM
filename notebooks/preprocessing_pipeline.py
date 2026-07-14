"""
preprocessing_pipeline.py
=========================================================================
Transformadores custom y constructor del pipeline de preprocessing para el
proyecto de predicción de rendimiento académico (TFM).

OBJETIVO: encapsular todas las operaciones que APRENDEN parámetros del conjunto
de datos (medianas por grupo, frecuencias de categorías, escalado, selección por
correlación con el target) en transformadores compatibles con scikit-learn, de
modo que en validación cruzada se ajusten (.fit) SOLO con el fold de entrenamiento
y se apliquen (.transform) al fold de test. Esto elimina el data leakage que se
producía al calcular esas estadísticas sobre todo el dataset antes del split.

REPARTO DE RESPONSABILIDADES
----------------------------
Operaciones SEGURAS (van en el notebook 04, fila a fila, sin aprender del conjunto):
    - eliminar columnas fijas
    - log1p de asistencia
    - indicadores de presencia (sin_notas_1ev, tiene_dato__X, tiene_faltas_*)
    - imputación con CONSTANTE 0 de las notas base de 1EV (valor fijo, no estadística)

Operaciones con LEAKAGE (van aquí, dentro del pipeline, se reajustan por fold):
    - imputación por mediana de grupo (competencias y demografía) → GroupMedianImputer
    - imputación por mediana global (notas diarias)               → SimpleImputer(strategy="median")
    - frequency encoding (NivEstudio, NivCurso)                   → FrequencyEncoder
    - escalado                                                    → StandardScaler
    - selección por correlación con target                        → CorrelationTargetSelector
    - selección por baja varianza / alta correlación entre pares  → (incluidas en build_preprocessor)
=========================================================================
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.stats import spearmanr

from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


class _PandasMixin(TransformerMixin):
    """
    Mixin para que Pipeline.set_output(transform='pandas') no falle con nuestros
    transformadores custom. Todos ya devuelven DataFrames de pandas; este mixin
    solo declara la capacidad y aporta un get_feature_names_out por defecto.
    """
    def get_feature_names_out(self, input_features=None):
        names = getattr(self, "feature_names_out_", None)
        if names is not None:
            return np.asarray(names, dtype=object)
        return np.asarray(input_features, dtype=object) if input_features is not None else None


# =========================================================================
# 1. Imputador por mediana de grupo (con fallback global)
# =========================================================================
class GroupMedianImputer(_PandasMixin, BaseEstimator):
    """
    Imputa los NaN de cada columna con la mediana del grupo al que pertenece
    la fila (p.ej. mediana por NivEstudio). Si el grupo no tiene mediana
    (todo NaN) o el valor de grupo es desconocido en transform, usa la
    mediana global aprendida en fit.

    Parámetros
    ----------
    group_col : str
        Nombre de la columna de agrupación (p.ej. 'NivEstudio').
    target_cols : list[str] | None
        Columnas a imputar. Si None, se imputan todas las numéricas salvo group_col.

    Notas
    -----
    - Las medianas por grupo y la global se aprenden EXCLUSIVAMENTE en .fit
      (sobre el fold de entrenamiento). En .transform solo se aplican.
    - Espera y devuelve un DataFrame de pandas (set_output gestionado por sklearn).
    """

    def __init__(self, group_col: str, target_cols: list[str] | None = None):
        self.group_col = group_col
        self.target_cols = target_cols

    def fit(self, X: pd.DataFrame, y=None):
        X = self._ensure_df(X)
        if self.target_cols is None:
            self.target_cols_ = [
                c for c in X.select_dtypes(include="number").columns
                if c != self.group_col
            ]
        else:
            self.target_cols_ = [c for c in self.target_cols if c in X.columns]

        # Mediana por grupo para cada columna  →  dict[col] = Series indexado por grupo
        self.group_medians_ = {}
        self.global_medians_ = {}
        for col in self.target_cols_:
            self.global_medians_[col] = X[col].median()
            if self.group_col in X.columns:
                self.group_medians_[col] = X.groupby(self.group_col)[col].median()
            else:
                self.group_medians_[col] = pd.Series(dtype=float)
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = self._ensure_df(X).copy()
        for col in self.target_cols_:
            if col not in X.columns:
                continue
            mask = X[col].isna()
            if not mask.any():
                continue
            if self.group_col in X.columns:
                # Mapear cada fila a la mediana de su grupo
                fill_group = X.loc[mask, self.group_col].map(self.group_medians_[col])
                X.loc[mask, col] = fill_group.values
            # Fallback global para lo que siga NaN (grupo desconocido o sin mediana)
            still = X[col].isna()
            if still.any():
                gm = self.global_medians_[col]
                # Si global_median también es NaN (todos NaN en train), usar 0
                X.loc[still, col] = gm if not pd.isna(gm) else 0.0
        return X

    @staticmethod
    def _ensure_df(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError("GroupMedianImputer espera un pandas DataFrame.")
        return X


# =========================================================================
# 1b. Centrado por grupo (edad relativa al curso, SIN leakage)
# =========================================================================
class GroupCenterer(_PandasMixin, BaseEstimator):
    """
    Resta a `col` la media de su grupo (`group_col`), aprendida en fit.
    Sustituye la 'edad_relativa' que antes se calculaba globalmente en el
    assembly: aquí la media por grupo se aprende SOLO con el fold de train,
    por lo que va dentro del pipeline y NO filtra información del test.

    - edad_inicio (cruda) → edad relativa al curso (NivCurso) tras el centrado.
    - Grupo no visto en transform, o sin media → se usa la media global de fit.
    - Si `col` no está en X, el transformador es un no-op (seguro de encadenar).
    """

    def __init__(self, col: str, group_col: str):
        self.col = col
        self.group_col = group_col

    def fit(self, X: pd.DataFrame, y=None):
        X = self._ensure_df(X)
        self.global_mean_ = float(X[self.col].mean()) if self.col in X.columns else 0.0
        if self.col in X.columns and self.group_col in X.columns:
            self.group_means_ = X.groupby(self.group_col)[self.col].mean()
        else:
            self.group_means_ = pd.Series(dtype=float)
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = self._ensure_df(X).copy()
        if self.col not in X.columns:
            return X
        if self.group_col in X.columns and len(self.group_means_):
            ref = X[self.group_col].map(self.group_means_)
            if hasattr(ref, "fillna"):
                ref = ref.fillna(self.global_mean_)
        else:
            ref = self.global_mean_
        X[self.col] = X[self.col] - ref
        return X

    @staticmethod
    def _ensure_df(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError("GroupCenterer espera un pandas DataFrame.")
        return X


# =========================================================================
# 2. Frequency encoder
# =========================================================================
class FrequencyEncoder(_PandasMixin, BaseEstimator):
    """
    Reemplaza cada columna categórica indicada por la frecuencia relativa de
    cada categoría, aprendida en fit. Crea columnas '<col>_freq' y elimina la
    original. Categorías no vistas en transform reciben frecuencia 0.

    Parámetros
    ----------
    cols : list[str]
        Columnas categóricas a codificar por frecuencia.
    drop_original : bool
        Si True (por defecto) elimina la columna categórica original.
    """

    def __init__(self, cols: list[str], drop_original: bool = True):
        self.cols = cols
        self.drop_original = drop_original

    def fit(self, X: pd.DataFrame, y=None):
        X = self._ensure_df(X)
        self.freqs_ = {}
        for col in self.cols:
            if col in X.columns:
                self.freqs_[col] = X[col].value_counts(normalize=True)
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = self._ensure_df(X).copy()
        for col, freq in self.freqs_.items():
            if col not in X.columns:
                continue
            X[f"{col}_freq"] = X[col].map(freq).fillna(0.0)
            if self.drop_original:
                X = X.drop(columns=[col])
        return X

    @staticmethod
    def _ensure_df(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError("FrequencyEncoder espera un pandas DataFrame.")
        return X


# =========================================================================
# 3. One-hot manual para niveles principales (umbral de frecuencia)
# =========================================================================
class TopCategoryOneHot(_PandasMixin, BaseEstimator):
    """
    Crea dummies one-hot solo para las categorías de `col` que en fit superan
    `min_count` observaciones. Las categorías raras no generan columna (quedan
    implícitas en 'todas las dummies = 0'). No elimina la columna original
    (eso lo hace FrequencyEncoder si se encadena después).

    Aprende la lista de categorías principales SOLO en fit → sin leakage.
    """

    def __init__(self, col: str, min_count: int = 10, prefix: str = "niv_"):
        self.col = col
        self.min_count = min_count
        self.prefix = prefix

    def fit(self, X: pd.DataFrame, y=None):
        X = self._ensure_df(X)
        self.categories_ = []
        if self.col in X.columns:
            counts = X[self.col].value_counts()
            self.categories_ = counts[counts >= self.min_count].index.tolist()
        self.feature_names_ = [self._clean(cat) for cat in self.categories_]
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = self._ensure_df(X).copy()
        if self.col in X.columns:
            for cat, name in zip(self.categories_, self.feature_names_):
                X[name] = (X[self.col] == cat).astype(int)
        return X

    def _clean(self, cat: str) -> str:
        s = str(cat).lower().replace(" ", "_").replace(".", "").replace(",", "")
        return self.prefix + s[:20]

    @staticmethod
    def _ensure_df(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError("TopCategoryOneHot espera un pandas DataFrame.")
        return X


# =========================================================================
# 4. Selector por correlación con el target (Spearman)
# =========================================================================
class CorrelationTargetSelector(_PandasMixin, BaseEstimator):
    """
    Para cada par de features con |Pearson| > corr_threshold entre sí,
    elimina la que tenga MENOR |Spearman| con el target. La decisión de qué
    columna eliminar se aprende en fit usando y (el target del fold de train),
    por lo que debe ir DENTRO del pipeline para no filtrar información del test.

    También elimina, opcionalmente, columnas con varianza < var_threshold.

    Parámetros
    ----------
    corr_threshold : float
        Umbral de correlación absoluta entre pares de features (default 0.95).
    var_threshold : float
        Umbral de varianza mínima; columnas por debajo se eliminan (default 0.01).
    protected : list[str] | None
        Columnas que nunca se eliminan (p.ej. 'Ejercicio' si se usa como feature).

    Requiere y en fit. Devuelve DataFrame con el subconjunto de columnas elegido.
    """

    def __init__(self, corr_threshold: float = 0.95, var_threshold: float = 0.01,
                 protected: list[str] | None = None):
        self.corr_threshold = corr_threshold
        self.var_threshold = var_threshold
        self.protected = protected

    def fit(self, X: pd.DataFrame, y=None):
        X = self._ensure_df(X)
        if y is None:
            raise ValueError("CorrelationTargetSelector requiere y en fit.")
        y = np.asarray(y)
        protected = set(self.protected or [])

        cols = list(X.columns)
        drop = set()

        # 4a. Varianza casi nula
        stds = X[cols].std(numeric_only=True)
        for c in cols:
            if c in protected:
                continue
            if c in stds.index and stds[c] < self.var_threshold:
                drop.add(c)

        # 4b. Correlación alta entre pares → quitar el de menor |rho| con target
        remaining = [c for c in cols if c not in drop]
        corr = X[remaining].corr().abs()
        upper = corr.where(np.triu(np.ones(corr.shape), k=1).astype(bool))
        pairs = [
            (i, j, upper.loc[i, j])
            for j in upper.columns for i in upper.index
            if pd.notna(upper.loc[i, j]) and upper.loc[i, j] > self.corr_threshold
        ]
        # Spearman de cada feature con el target (cache)
        rho_cache = {}

        def rho(col):
            if col not in rho_cache:
                v = X[col].values
                if np.std(v) == 0:
                    rho_cache[col] = 0.0
                else:
                    r = spearmanr(v, y).correlation
                    rho_cache[col] = 0.0 if np.isnan(r) else abs(r)
            return rho_cache[col]

        for a, b, _ in sorted(pairs, key=lambda t: -t[2]):
            if a in drop or b in drop:
                continue
            if a in protected and b in protected:
                continue
            if a in protected:
                drop.add(b); continue
            if b in protected:
                drop.add(a); continue
            drop.add(a if rho(a) < rho(b) else b)

        self.columns_to_keep_ = [c for c in cols if c not in drop]
        self.columns_dropped_ = sorted(drop)
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = self._ensure_df(X)
        keep = [c for c in self.columns_to_keep_ if c in X.columns]
        return X[keep].copy()

    def get_feature_names_out(self, input_features=None):
        return np.asarray(self.columns_to_keep_, dtype=object)

    @staticmethod
    def _ensure_df(X):
        if not isinstance(X, pd.DataFrame):
            raise TypeError("CorrelationTargetSelector espera un pandas DataFrame.")
        return X


# =========================================================================
# 5. Constructor del pipeline de preprocessing "leaky-safe"
# =========================================================================
def build_preprocessor(
    df_columns: list[str],
    group_col: str = "NivEstudio",
    nivcurso_col: str = "NivCurso",
    scale: bool = True,
    impute: bool = True,
    corr_threshold: float = 0.95,
    var_threshold: float = 0.01,
    protected: list[str] | None = None,
) -> Pipeline:
    """
    Devuelve un Pipeline de sklearn que aplica, en orden y aprendiendo TODO
    desde el fold de entrenamiento:

        1. GroupMedianImputer(NivEstudio)  → competencias + demografía + lo que quede NaN
        2. TopCategoryOneHot(NivEstudio)   → dummies de niveles con >=10 obs
        3. FrequencyEncoder(NivEstudio, NivCurso) → *_freq y elimina las categóricas
        4. CorrelationTargetSelector       → varianza baja + correlación con target (usa y)
        5. StandardScaler (opcional)       → escalado final

    El resultado es un único objeto que se mete dentro de cada modelo en la CV:
        modelo_full = Pipeline([("prep", build_preprocessor(...)), ("clf", XGBClassifier(...))])

    Parámetros
    ----------
    df_columns : list[str]
        Columnas que tendrá X (para informar de las categóricas presentes).
    group_col, nivcurso_col : str
        Nombres de las columnas categóricas.
    scale : bool
        Si añadir StandardScaler al final (útil para modelos lineales; inocuo para árboles).
    protected : list[str] | None
        Features que el selector nunca debe eliminar.
    """
    protected = protected or []

    steps = []

    # 0. Edad relativa al curso SIN leakage: centra 'edad_inicio' por NivCurso con la
    #    media aprendida en train (no-op si la columna no está). Reemplaza la antigua
    #    'edad_relativa' calculada globalmente en el assembly. Va ANTES de codificar
    #    NivCurso (que luego lo elimina freq_encode).
    steps.append((
        "edad_center",
        GroupCenterer(col="edad_inicio", group_col=nivcurso_col),
    ))

    # 1. Imputación por mediana de grupo (OPCIONAL). target_cols=None → todas las numéricas.
    #    impute=False → se deja pasar el NaN para que el modelo de árbol (XGBoost) lo
    #    maneje nativamente, preservando la señal "este nivel/colegio no tiene esa materia"
    #    en vez de inventar una mediana. RandomForest (sklearn) y LR sí requieren impute=True.
    if impute:
        steps.append((
            "group_impute",
            GroupMedianImputer(group_col=group_col, target_cols=None),
        ))

    # 2. Dummies one-hot de niveles principales (antes de eliminar la categórica)
    steps.append((
        "niv_onehot",
        TopCategoryOneHot(col=group_col, min_count=10, prefix="niv_"),
    ))

    # 3. Frequency encoding de NivEstudio y NivCurso (elimina las originales)
    steps.append((
        "freq_encode",
        FrequencyEncoder(cols=[group_col, nivcurso_col], drop_original=True),
    ))

    # 4. Selección de features (varianza + correlación con target). USA y.
    steps.append((
        "feat_select",
        CorrelationTargetSelector(
            corr_threshold=corr_threshold,
            var_threshold=var_threshold,
            protected=protected,
        ),
    ))

    # 5. Escalado final opcional
    if scale:
        scaler = StandardScaler()
        scaler.set_output(transform="pandas")
        steps.append(("scale", scaler))

    pipe = Pipeline(steps)
    pipe.set_output(transform="pandas")
    return pipe


# =========================================================================
# 6. XGBoost con balanceo de clases incorporado
# =========================================================================
try:
    import xgboost as xgb
    from sklearn.utils.class_weight import compute_sample_weight

    class BalancedXGBClassifier(xgb.XGBClassifier):
        """
        XGBClassifier que calcula sample_weight='balanced' internamente en fit().
        Funciona dentro de Pipeline + cross_validate sin pasar fit_params externos:
        los pesos se derivan de las y del fold de entrenamiento, sin leakage.
        """

        def fit(self, X, y, **kwargs):
            kwargs.setdefault("sample_weight", compute_sample_weight("balanced", y))
            return super().fit(X, y, **kwargs)

except ImportError:
    pass  # xgboost no instalado; BalancedXGBClassifier no disponible


# =========================================================================
# 7. Utilidad: comprobar que el pipeline no deja NaN ni columnas object
# =========================================================================
def assert_clean_output(X_out: pd.DataFrame) -> None:
    """Verificación defensiva del resultado del pipeline."""
    n_nan = int(np.asarray(X_out).astype(float).reshape(-1).__len__()) and int(pd.DataFrame(X_out).isna().sum().sum())
    obj = pd.DataFrame(X_out).select_dtypes(include="object").columns.tolist()
    assert n_nan == 0, f"El pipeline dejó {n_nan} NaN."
    assert not obj, f"El pipeline dejó columnas no numéricas: {obj}"
