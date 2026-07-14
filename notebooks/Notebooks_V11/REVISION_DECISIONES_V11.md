# Revisión de decisiones — Pipeline V11 (nivel TFM)

Con el dataset de **1.210 obs** (vs 491 de V8), muchas decisiones tomadas "por falta de
datos" ya no se justifican. Esta es la auditoría notebook por notebook.

## 0. Encadenamiento de datasets (FIX obligatorio)

Las rutas heredadas de V9 están rotas (cada NB lee un nombre distinto). Cadena canónica V11:

| NB | LEE | ESCRIBE |
|----|-----|---------|
| 01_assembly | Q01/Q02/Q03/Q04/Q05 (csv) | `dataset_v11.csv` |
| 02_features_competencias | `dataset_v11.csv` | `dataset_v11.csv` (enriquecido) |
| 03_eda | `dataset_v11.csv` | — (solo lectura) |
| 04_nulos_outliers | `dataset_v11.csv` | — (solo lectura) |
| 05_preprocessing | `dataset_v11.csv` | `dataset_v11_preproc.csv` |
| 06_feature_engineering | `dataset_v11_preproc.csv` | `dataset_v11_fe.csv` |
| 07_feature_selection | `dataset_v11_fe.csv` | `selected_features_v11.json` |
| 08_modelado | `dataset_v11_fe.csv` + json | — (resultados) |

## 1. Decisiones OBSOLETAS (quitar — eran artefactos de V8)

| Decisión V8 | Por qué se quita en V11 |
|-------------|--------------------------|
| **Notas diarias (solo 2020, 83% NaN)** | No están en el assembly V11; inyectaban NaN masivo y sesgo por año. Eliminar todas las referencias en 04/05/06. |
| **`origen_nota_final`, `numero_eval_max`** | Columnas de V8 que el target V11 no tiene. Quitar de DROP lists, `clasificar_grupo`, auditorías. |
| **"El modelo no generaliza entre cohortes → falta data"** (04, 08) | **Ahora SÍ hay datos** (2010-2020). Reemplazar la disculpa por **validación temporal real**. |
| Exclusión años 2012/2015/2016 | Ya resuelto: el gate SQL + filtro <4 asignaturas gobiernan el cohorte. |

## 2. Decisiones a MEJORAR (la escasez ya no aplica)

| Tema | V8 (escasez) | V11 (mejora) |
|------|--------------|--------------|
| **Validación temporal** | Se intentó y "falló por falta de datos" | Con 883 obs de 2010/2011 y 341 de 2019/2020 → **train en cohortes viejas, test en nuevas**. Es una contribución central del TFM (¿predice el futuro?). |
| **Granularidad de materias** | 8 competencias LOMLOE → 4 bloques (cobertura 25-40%) | V11 ya tiene **22 materias individuales + 4 bloques** → más granular que las 8 competencias. Mantener. |
| **Explicabilidad** | Importancia de features básica | **SHAP** sobre el modelo final → qué materia/bloque/demografía impulsa el riesgo (nivel TFM). |
| **Búsqueda de hiperparámetros** | Limitada por CV inestable con n=491 | Con n=1.210 la CV es estable → búsqueda wide+fine de XGBoost (ya prototipada). |

## 3. Decisiones que se MANTIENEN (bien fundadas)

- Separación leaky / no-leaky (transformaciones que aprenden parámetros van dentro del fold). ✓
- `IdNEE → tiene_NEE` (binarizar código nominal). ✓
- `edad_relativa` extrema: mantener (predictiva, alumnos NEE/repetidores). ✓
- `log1p` en asistencia (ahora 66% con registro real). ✓
- `scorer_academico` (coste-sensible) para selección y evaluación. ✓
- Nested CV (5×3) con pipeline por fold. ✓

## 4. Punto nuevo de V11 — materias individuales con NaN estructural

Las 22 `mat__X` son NaN cuando el alumno no cursa esa materia (estructural, no error).
Decisión: para árboles (XGBoost) **dejar NaN** (los maneja nativamente) + indicador de
cobertura; para LR, imputar por mediana de nivel. El selector por correlación descarta las
de cobertura muy baja. A validar en 05/07.
