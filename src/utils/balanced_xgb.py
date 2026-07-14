from sklearn.utils.class_weight import compute_sample_weight
from xgboost import XGBClassifier


class BalancedXGB(XGBClassifier):
    """XGBClassifier con balanceo de clases por sample_weight en cada fit."""

    def fit(self, X, y, **kw):
        sw = compute_sample_weight("balanced", y)
        return super().fit(X, y, sample_weight=sw, **kw)
