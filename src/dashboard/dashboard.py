"""
Dashboard de predicción de rendimiento académico — TFM
Profesor-facing: semáforo de aula, ficha de alumno y métricas de centro.

Lanzar (desde la raíz del TFM):
    streamlit run src/dashboard/app.py

Prerrequisito: haber ejecutado save_model_v11.py para generar models/model_v11_xgb.pkl
"""
from __future__ import annotations

import sys
import pickle
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

BASE_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.extend([str(BASE_DIR), str(BASE_DIR / "notebooks")])

from src.utils.metrics import COST_MATRIX, score_academico  # noqa: E402
from src.utils.balanced_xgb import BalancedXGB  # noqa: E402, F401 — necesario para deserializar el pkl

# ─────────────────────────────────────────────────────────────────────────────
# Constantes
# ─────────────────────────────────────────────────────────────────────────────
CAT_ORDER = ["buen_alumno", "en_riesgo", "con_dificultades"]
LABEL = {
    "buen_alumno": "Buen alumno",
    "en_riesgo": "En riesgo",
    "con_dificultades": "Con dificultades",
}
COLOR = {
    "buen_alumno": "#27ae60",
    "en_riesgo": "#f39c12",
    "con_dificultades": "#e74c3c",
}
EMOJI = {
    "buen_alumno": "🟢",
    "en_riesgo": "🟡",
    "con_dificultades": "🔴",
}
BLOCK_COLS = {
    "LING": "nota_media__LING",
    "STEM": "nota_media__STEM",
    "SOC": "nota_media__SOC",
    "PERS": "nota_media__PERS",
}

# ─────────────────────────────────────────────────────────────────────────────
# Carga de modelo y datos (cacheados)
# ─────────────────────────────────────────────────────────────────────────────


@st.cache_resource(show_spinner="Cargando modelo …")
def load_model() -> dict:
    model_path = BASE_DIR / "models" / "model_v11_xgb.pkl"
    if not model_path.exists():
        st.error(
            f"Modelo no encontrado en `{model_path}`.\n\n"
            "Ejecuta primero:\n```\npython src/dashboard/save_model_v11.py\n```"
        )
        st.stop()
    with open(model_path, "rb") as f:
        return pickle.load(f)


@st.cache_data(show_spinner="Cargando dataset …")
def load_data() -> pd.DataFrame:
    return pd.read_csv(BASE_DIR / "data" / "dataset_v11_fe.csv")


@st.cache_data(show_spinner="Generando predicciones …")
def predict_all(_model: dict, df: pd.DataFrame) -> pd.DataFrame:
    pipe = _model["pipeline"]
    feat_cols = _model["feature_cols"]
    X = df[feat_cols].copy()

    proba = pipe.predict_proba(X)
    expected_cost = proba @ COST_MATRIX
    pred_num = expected_cost.argmin(axis=1)

    result = df[
        [c for c in ["Ejercicio", "NivEstudio", "NivCurso", "IsRepetidor", "Sexo",
                      "nota_media_1ev", "nota_min_1ev", "nota_max_1ev",
                      "n_suspensos_1ev", "pct_aprobado_1ev",
                      "categoria_target", "target_num"]
         if c in df.columns]
    ].copy()

    result["pred_num"] = pred_num
    result["pred_cat"] = pd.Categorical(
        [CAT_ORDER[i] for i in pred_num], categories=CAT_ORDER, ordered=True
    )
    result["P_buen"] = proba[:, 0].round(3)
    result["P_riesgo"] = proba[:, 1].round(3)
    result["P_dificulta"] = proba[:, 2].round(3)
    result["score_acad"] = score_academico(
        result["target_num"].values, pred_num
    ) if "target_num" in result.columns else np.nan

    for b, col in BLOCK_COLS.items():
        if col in df.columns:
            result[f"nota_{b}"] = df[col].round(2)

    # Calidad de datos: nº de bloques con dato y nº de asignaturas totales
    tc_cols = [f"tiene_dato__{b}" for b in ["LING", "STEM", "SOC", "PERS"]]
    present = [c for c in tc_cols if c in df.columns]
    if present:
        result["n_bloques"] = df[present].sum(axis=1).astype(int)
    if "n_aprobadas_1ev" in df.columns and "n_suspensos_1ev" in df.columns:
        result["n_asignaturas_1ev"] = (df["n_aprobadas_1ev"] + df["n_suspensos_1ev"]).astype(int)

    return result.reset_index(drop=True)


def filter_df(df: pd.DataFrame, ejercicios, niveles, cursos) -> pd.DataFrame:
    mask = pd.Series(True, index=df.index)
    if ejercicios:
        mask &= df["Ejercicio"].isin(ejercicios)
    if niveles:
        mask &= df["NivEstudio"].isin(niveles)
    if cursos:
        mask &= df["NivCurso"].isin(cursos)
    return df[mask]


# ─────────────────────────────────────────────────────────────────────────────
# Helpers de visualización
# ─────────────────────────────────────────────────────────────────────────────


def kpi_metrics(sub: pd.DataFrame):
    counts = sub["pred_cat"].value_counts().reindex(CAT_ORDER, fill_value=0)
    total = len(sub)
    cols = st.columns(3)
    for col, cat in zip(cols, CAT_ORDER):
        n = int(counts[cat])
        pct = 100 * n / total if total else 0
        col.metric(
            label=f"{EMOJI[cat]} {LABEL[cat]}",
            value=f"{n}",
            delta=f"{pct:.1f}%",
            delta_color="off",
        )


def distribution_chart(sub: pd.DataFrame) -> go.Figure:
    counts = sub["pred_cat"].value_counts().reindex(CAT_ORDER, fill_value=0)
    fig = go.Figure(
        go.Bar(
            x=[LABEL[c] for c in CAT_ORDER],
            y=[counts[c] for c in CAT_ORDER],
            marker_color=[COLOR[c] for c in CAT_ORDER],
            text=[counts[c] for c in CAT_ORDER],
            textposition="outside",
        )
    )
    fig.update_layout(
        showlegend=False,
        margin=dict(t=20, b=10, l=10, r=10),
        height=280,
        yaxis_title="N.º alumnos",
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
    )
    return fig


def semaforo_table(sub: pd.DataFrame) -> pd.DataFrame:
    display_cols = {
        "NivEstudio": "Etapa",
        "NivCurso": "Curso",
        "nota_media_1ev": "Media 1EV",
        "n_asignaturas_1ev": "N Asig.",
        "n_bloques": "Bloques",
        "n_suspensos_1ev": "Susp. 1EV",
        "pred_cat": "Predicción",
        "P_buen": "P(bueno)",
        "P_riesgo": "P(riesgo)",
        "P_dificulta": "P(dificulta)",
    }
    if "IsRepetidor" in sub.columns:
        display_cols["IsRepetidor"] = "Repetidor"
    cols = [c for c in display_cols if c in sub.columns]
    table = sub[cols].rename(columns=display_cols).copy()
    table["Predicción"] = table["Predicción"].map(
        lambda x: f"{EMOJI.get(x, '')} {LABEL.get(x, x)}"
    )
    if "Alumno" not in table.columns:
        table.insert(0, "ID", range(1, len(table) + 1))
    return table


BLOCK_LABELS = {
    "LING": "Lenguas (LING)",
    "STEM": "Ciencias y Matemáticas (STEM)",
    "SOC":  "Sociales y Arte (SOC)",
    "PERS": "Ed. Física / Religión (PERS)",
}


def block_bars(row: pd.Series) -> go.Figure:
    """Barras horizontales por bloque: nota_media + nota_min. Más legible que el radar."""
    blocks   = ["LING", "STEM", "SOC", "PERS"]
    labels   = [BLOCK_LABELS[b] for b in blocks]
    medias   = [float(row[f"nota_{b}"]) if f"nota_{b}" in row.index and not pd.isna(row[f"nota_{b}"]) else None for b in blocks]
    mins_raw = [f"nota_min__{b}" for b in blocks]

    bar_colors, bar_vals, bar_text, hover = [], [], [], []
    for b, med in zip(blocks, medias):
        if med is None:
            bar_colors.append("#d5d8dc")
            bar_vals.append(0)
            bar_text.append("Sin datos")
            hover.append("Sin datos registrados")
        else:
            color = "#27ae60" if med >= 5 else "#e74c3c"
            bar_colors.append(color)
            bar_vals.append(med)
            bar_text.append(f"{med:.1f}")
            hover.append(f"Media: {med:.2f}")

    fig = go.Figure()

    # Barras principales (nota_media por bloque)
    fig.add_trace(go.Bar(
        x=bar_vals,
        y=labels,
        orientation="h",
        marker_color=bar_colors,
        text=bar_text,
        textposition="outside",
        cliponaxis=False,
        hovertext=hover,
        hoverinfo="text+y",
        name="Nota media bloque",
        width=0.5,
    ))

    # Línea de aprobado
    fig.add_vline(x=5, line_dash="dash", line_color="#7f8c8d", line_width=1.5,
                  annotation_text="Aprobado (5)", annotation_position="top right",
                  annotation_font_size=11, annotation_font_color="#7f8c8d")

    fig.update_layout(
        xaxis=dict(range=[0, 11], title="Nota media 1EV (0–10)", tickvals=[0,2,4,5,6,8,10]),
        showlegend=False,
        height=260,
        margin=dict(t=10, b=30, l=10, r=60),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        bargap=0.3,
    )
    return fig


def proba_bars(row: pd.Series) -> go.Figure:
    cats = CAT_ORDER
    vals = [float(row.get("P_buen", 0)), float(row.get("P_riesgo", 0)), float(row.get("P_dificulta", 0))]
    fig = go.Figure(
        go.Bar(
            x=vals,
            y=[LABEL[c] for c in cats],
            orientation="h",
            marker_color=[COLOR[c] for c in cats],
            text=[f"{v:.1%}" for v in vals],
            textposition="auto",
        )
    )
    fig.update_layout(
        xaxis=dict(range=[0, 1], tickformat=".0%"),
        showlegend=False,
        height=200,
        margin=dict(t=10, b=10, l=10, r=10),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
    )
    return fig


def shap_bar(row_index: int, model: dict, df: pd.DataFrame) -> go.Figure | None:
    try:
        import shap  # noqa: PLC0415
    except ImportError:
        return None

    pipe = model["pipeline"]
    feat_cols = model["feature_cols"]
    row = df.iloc[[row_index]][feat_cols]

    prep = pipe.named_steps["prep"]
    clf = pipe.named_steps["clf"]
    Xt = prep.transform(row)
    if not isinstance(Xt, pd.DataFrame):
        Xt = pd.DataFrame(Xt)

    explainer = shap.TreeExplainer(clf)
    sv = explainer.shap_values(Xt)

    # SHAP siempre respecto a 'con_dificultades' → eje de riesgo universal
    risk_idx = CAT_ORDER.index("con_dificultades")

    if isinstance(sv, list):
        sv_signed = sv[risk_idx][0]
    else:
        a = np.asarray(sv)
        sv_signed = a[0, :, risk_idx] if a.ndim == 3 else a[0]

    feat_names = Xt.columns.tolist() if isinstance(Xt, pd.DataFrame) else [f"f{i}" for i in range(len(sv_signed))]

    # Top 12 por importancia absoluta, conservando el signo
    imp = pd.Series(sv_signed, index=feat_names)
    imp = imp.reindex(imp.abs().sort_values(ascending=False).head(12).index)
    imp = imp.sort_values()  # ascendente → la barra más importante queda arriba

    # Detectar qué features son NaN en la fila original (antes de preprocesar)
    raw_row = df.iloc[row_index]
    nan_feats = set(feat_cols) & set(raw_row.index[raw_row.isna()])

    # Etiquetar features NaN con "(sin dato)" para distinguirlas de notas reales
    display_names = [
        f"{name}  ·sin dato·" if name in nan_feats else name
        for name in imp.index
    ]

    # Rojo = aumenta riesgo (positivo), verde = protege (negativo)
    # Features NaN: borde punteado mediante opacidad reducida para indicar que es ausencia, no valor real
    bar_colors = ["#e74c3c" if v > 0 else "#27ae60" for v in imp.values]
    bar_opacity = [0.55 if name in nan_feats else 1.0 for name in imp.index]

    fig = go.Figure(
        go.Bar(
            x=imp.values,
            y=display_names,
            orientation="h",
            marker_color=bar_colors,
            marker_opacity=bar_opacity,
            text=[f"{v:+.3f}" for v in imp.values],
            textposition="outside",
            cliponaxis=False,
        )
    )
    fig.add_vline(x=0, line_color="#34495e", line_width=1.2)
    fig.update_layout(
        title="Perfil de riesgo del alumno (top 12 factores)",
        xaxis_title="← factor protector  |  factor de riesgo →",
        height=380,
        margin=dict(t=40, b=10, l=10, r=70),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
    )
    return fig


def confusion_heatmap(sub: pd.DataFrame) -> go.Figure | None:
    if "target_num" not in sub.columns:
        return None
    from sklearn.metrics import confusion_matrix  # noqa: PLC0415

    y_true = sub["target_num"].values
    y_pred = sub["pred_num"].values
    cm = confusion_matrix(y_true, y_pred, labels=[0, 1, 2])
    labels = [LABEL[c] for c in CAT_ORDER]
    fig = px.imshow(
        cm,
        x=labels,
        y=labels,
        color_continuous_scale="Greens",
        labels=dict(x="Predicho", y="Real"),
        text_auto=True,
    )
    fig.update_layout(
        height=350,
        margin=dict(t=10, b=10, l=10, r=10),
        paper_bgcolor="rgba(0,0,0,0)",
        coloraxis_showscale=False,
    )
    return fig


# ─────────────────────────────────────────────────────────────────────────────
# Layout principal
# ─────────────────────────────────────────────────────────────────────────────


def main():
    st.set_page_config(
        page_title="Predicción de Rendimiento — TFM",
        page_icon="📊",
        layout="wide",
    )

    model = load_model()
    df_raw = load_data()
    df = predict_all(model, df_raw)

    # ── Sidebar ──────────────────────────────────────────────────────────────
    st.sidebar.title("Filtros")

    ejercicios_all = sorted(df["Ejercicio"].dropna().unique().tolist())
    ejercicios_sel = st.sidebar.multiselect(
        "Ejercicio (año académico)",
        ejercicios_all,
        default=ejercicios_all,
        help="Cursos académicos disponibles en el dataset.",
    )

    niveles_all = sorted(df["NivEstudio"].dropna().unique().tolist()) if "NivEstudio" in df.columns else []
    niveles_sel = st.sidebar.multiselect("Etapa educativa", niveles_all, default=niveles_all)

    cursos_candidates = df[df["NivEstudio"].isin(niveles_sel)]["NivCurso"].dropna().unique() if niveles_sel and "NivCurso" in df.columns else df["NivCurso"].dropna().unique() if "NivCurso" in df.columns else []
    cursos_all = sorted(cursos_candidates.tolist())
    cursos_sel = st.sidebar.multiselect("Curso", cursos_all, default=cursos_all)

    sub = filter_df(df, ejercicios_sel, niveles_sel, cursos_sel)

    st.sidebar.markdown("---")
    st.sidebar.metric("Alumnos seleccionados", len(sub), f"de {len(df)} total")

    # ── Tabs ──────────────────────────────────────────────────────────────────
    tab1, tab2, tab3 = st.tabs(
        ["📊 Vista 1 — Semáforo de Aula", "🔍 Vista 2 — Ficha de Alumno", "🏫 Vista 3 — Métricas de Centro"]
    )

    # ─────────────────────────────────────────────────────────────────────────
    # VISTA 1 — SEMÁFORO DE AULA
    # ─────────────────────────────────────────────────────────────────────────
    with tab1:
        st.header("Semáforo de aula")
        st.caption(
            "Predicción coste-sensible: clasifica cada alumno según el riesgo de suspensos en la "
            "evaluación final, usando exclusivamente datos del primer trimestre."
        )

        if sub.empty:
            st.warning("Sin alumnos con los filtros seleccionados.")
        else:
            kpi_metrics(sub)
            st.markdown("---")

            col_chart, col_table = st.columns([1, 2], gap="large")
            with col_chart:
                st.subheader("Distribución de riesgo")
                st.plotly_chart(distribution_chart(sub), use_container_width=True)

                if "target_num" in sub.columns:
                    sa = score_academico(sub["target_num"].values, sub["pred_num"].values)
                    st.metric(
                        "Score académico (coste-sensible)",
                        f"{sa:.3f}",
                        help="1.0 = predicción perfecta. Penaliza más los errores costosos "
                             "(predecir 'buen alumno' cuando hay dificultades).",
                    )

            with col_table:
                st.subheader("Listado de alumnos")
                table = semaforo_table(sub)

                def row_style(row):
                    pred = str(row.get("Predicción", ""))
                    if "Con dificultades" in pred:
                        bg = "#fde8e8"
                    elif "En riesgo" in pred:
                        bg = "#fef9e7"
                    else:
                        bg = "#eafaf1"
                    return [f"background-color: {bg}"] * len(row)

                st.dataframe(
                    table.style.apply(row_style, axis=1),
                    use_container_width=True,
                    hide_index=True,
                    height=400,
                )

    # ─────────────────────────────────────────────────────────────────────────
    # VISTA 2 — FICHA DE ALUMNO
    # ─────────────────────────────────────────────────────────────────────────
    with tab2:
        st.header("Ficha de alumno")
        st.caption("Selecciona un alumno del subconjunto filtrado para ver su predicción detallada.")

        if sub.empty:
            st.warning("Sin alumnos con los filtros seleccionados.")
        else:
            alumno_id = st.selectbox(
                "Alumno (ID en la selección actual)",
                options=sub.index.tolist(),
                format_func=lambda i: (
                    f"ID {i + 1} — {sub.loc[i, 'NivEstudio']} / {sub.loc[i, 'NivCurso']} "
                    f"| Media 1EV: {sub.loc[i, 'nota_media_1ev']:.2f}"
                    if "NivEstudio" in sub.columns and "NivCurso" in sub.columns else f"ID {i + 1}"
                ),
            )
            row = sub.loc[alumno_id]
            pred_cat = str(row["pred_cat"])

            st.markdown(
                f"### {EMOJI.get(pred_cat, '')} Predicción: **{LABEL.get(pred_cat, pred_cat)}**",
            )

            col_prob, col_blocks = st.columns(2, gap="large")
            with col_prob:
                st.subheader("Probabilidades por clase")
                st.plotly_chart(proba_bars(row), use_container_width=True)

                meta_items = []
                if "NivEstudio" in row.index:
                    meta_items.append(f"**Etapa:** {row['NivEstudio']}")
                if "NivCurso" in row.index:
                    meta_items.append(f"**Curso:** {row['NivCurso']}")
                if "Ejercicio" in row.index:
                    meta_items.append(f"**Año:** {int(row['Ejercicio'])}")
                if "IsRepetidor" in row.index:
                    meta_items.append(f"**Repetidor:** {'Sí' if row['IsRepetidor'] else 'No'}")
                if "nota_media_1ev" in row.index:
                    n_asig = int(row["n_asignaturas_1ev"]) if "n_asignaturas_1ev" in row.index else "?"
                    meta_items.append(f"**Media 1EV:** {row['nota_media_1ev']:.2f} *({n_asig} asignaturas)*")
                if "n_suspensos_1ev" in row.index:
                    meta_items.append(f"**Susp. en 1EV:** {int(row['n_suspensos_1ev'])}")
                if "n_bloques" in row.index:
                    meta_items.append(f"**Bloques con datos:** {int(row['n_bloques'])} / 4")

                st.markdown("  \n".join(meta_items))

                # Warning de datos incompletos
                n_bloques = int(row["n_bloques"]) if "n_bloques" in row.index else 4
                n_asig_val = int(row["n_asignaturas_1ev"]) if "n_asignaturas_1ev" in row.index else 99
                if n_bloques <= 2:
                    st.warning(
                        f"⚠️ **Predicción con datos limitados**: {n_asig_val} asignatura(s) "
                        f"registrada(s) en 1EV ({n_bloques}/4 bloques temáticos). "
                        "La media mostrada no refleja el perfil académico completo del alumno. "
                        "El modelo interpreta la ausencia de datos como señal, "
                        "lo que puede corresponder a un programa de refuerzo o a datos no registrados en el sistema."
                    )

            with col_blocks:
                st.subheader("Nota media por bloque (1EV)")
                st.plotly_chart(block_bars(row), use_container_width=True)
                st.caption("Verde ≥ 5 · Rojo < 5 · Gris = sin datos registrados en el sistema")

            st.markdown("---")
            st.subheader("Factores que impulsan la predicción (SHAP)")
            with st.spinner("Calculando importancias SHAP …"):
                fig_shap = shap_bar(alumno_id, model, df_raw)
            if fig_shap:
                st.plotly_chart(fig_shap, use_container_width=True)
                st.caption(
                    "Rojo = aumenta el riesgo · Verde = factor protector. "
                    "Barras semitransparentes (·sin dato·) = el dato estaba ausente en 1EV; "
                    "el modelo interpreta la ausencia como señal, no una nota real."
                )
            else:
                st.info("SHAP no disponible. Instala `shap` con `pip install shap`.")

    # ─────────────────────────────────────────────────────────────────────────
    # VISTA 3 — MÉTRICAS DE CENTRO
    # ─────────────────────────────────────────────────────────────────────────
    with tab3:
        st.header("Métricas de centro")
        st.caption("Resumen del rendimiento predictivo sobre los datos históricos disponibles.")

        if sub.empty:
            st.warning("Sin alumnos con los filtros seleccionados.")
        else:
            col_cm, col_by_level = st.columns(2, gap="large")

            with col_cm:
                st.subheader("Matriz de confusión")
                fig_cm = confusion_heatmap(sub)
                if fig_cm:
                    st.plotly_chart(fig_cm, use_container_width=True)
                    st.caption("Filas = clase real · Columnas = clase predicha.")
                else:
                    st.info("Sin datos de target real para comparar.")

            with col_by_level:
                st.subheader("Score académico por etapa")
                if "target_num" in sub.columns and "NivEstudio" in sub.columns:
                    rows = []
                    for niv, g in sub.groupby("NivEstudio"):
                        if len(g) < 5:
                            continue
                        sa = score_academico(g["target_num"].values, g["pred_num"].values)
                        acc = (g["target_num"].values == g["pred_num"].values).mean()
                        rows.append({"Etapa": niv, "n": len(g), "Score acad.": round(sa, 3), "Accuracy": round(acc, 3)})
                    if rows:
                        level_df = pd.DataFrame(rows).sort_values("Score acad.", ascending=False)
                        st.dataframe(level_df, hide_index=True, use_container_width=True)

                        fig_lv = px.bar(
                            level_df,
                            x="Etapa",
                            y="Score acad.",
                            color="Score acad.",
                            color_continuous_scale=["#e74c3c", "#f39c12", "#27ae60"],
                            range_color=[0.7, 1.0],
                            text="Score acad.",
                        )
                        fig_lv.update_traces(texttemplate="%{text:.3f}", textposition="outside")
                        fig_lv.update_layout(
                            showlegend=False,
                            height=280,
                            margin=dict(t=10, b=10),
                            coloraxis_showscale=False,
                            paper_bgcolor="rgba(0,0,0,0)",
                            plot_bgcolor="rgba(0,0,0,0)",
                        )
                        st.plotly_chart(fig_lv, use_container_width=True)
                    else:
                        st.info("Pocas observaciones por etapa para calcular métricas.")
                else:
                    st.info("Sin datos de target real.")

            st.markdown("---")
            st.subheader("Distribución por año y etapa")
            if "NivEstudio" in sub.columns and "Ejercicio" in sub.columns:
                pivot = (
                    sub.groupby(["Ejercicio", "NivEstudio"])
                    .size()
                    .reset_index(name="n")
                )
                fig_pivot = px.bar(
                    pivot,
                    x="Ejercicio",
                    y="n",
                    color="NivEstudio",
                    barmode="stack",
                    labels={"n": "Alumnos", "Ejercicio": "Año"},
                )
                fig_pivot.update_layout(
                    height=300,
                    margin=dict(t=10, b=10),
                    paper_bgcolor="rgba(0,0,0,0)",
                    plot_bgcolor="rgba(0,0,0,0)",
                )
                st.plotly_chart(fig_pivot, use_container_width=True)


if __name__ == "__main__":
    main()
