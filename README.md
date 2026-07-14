# TFM — Predicción de Rendimiento Académico Temprano

Predicción del rendimiento académico al final del año escolar usando exclusivamente 
datos del primer trimestre (notas, asistencia, criterios de evaluación).

## Objetivo

Dado un alumno al final del primer trimestre, predecir cuántas asignaturas 
suspenderá al final del año. Permite identificar alumnos en riesgo con tiempo 
suficiente para intervenir.

## Fuente de datos

Base de datos NewSys2049 — ERP Alexia de Educaria (gestión escolar).
2 centros, ~1.200 alumnos únicos, 17 ejercicios académicos.

El modelo de evaluación sigue la LOMLOE (Ley Orgánica 3/2020).
Ver `context/criterio_evaluacion.html` para el esquema completo de entidades.

## Estructura

```
TFM/
├── CLAUDE.md                         ← instrucciones para Claude (no tocar)
├── context/                          ← documentación del dominio y esquema
├── data/
│   ├── raw/                          ← CSVs sin procesar (no versionar)
│   ├── processed/                    ← datasets limpios y features construidas
│   └── exports/                      ← outputs para presentación
├── notebooks/                        ← exploración y desarrollo
│   └── archive/                      ← notebooks deprecados
├── src/
│   ├── queries/                      ← queries T-SQL organizadas por fase
│   │   ├── explorar/
│   │   ├── features/
│   │   └── target/
│   ├── extraction/
│   ├── features/
│   ├── models/
│   └── evaluation/
├── agents/                           ← protocolos de agentes por fase
├── outputs/
│   ├── figures/
│   ├── tables/
│   └── reports/
└── .claude/skills/                   ← contexto por dominio para Claude
```

## Stack

Python (pandas, scikit-learn, PyTorch) · SQL Server (T-SQL) · Jupyter · Claude Code
