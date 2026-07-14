"""
Utilidades de versionado para outputs de notebooks.

Uso al inicio del notebook:
    from src.utils.nb_output import NbOutput
    out = NbOutput('05_modelado')          # crea outputs/05_modelado/v{N}/

Al guardar una figura:
    out.savefig(fig, 'comparacion_modelos')  # → outputs/05_modelado/v3/comparacion_modelos.png

Al guardar métricas (append al historial global):
    out.log_metrics(res_df, extra={'features': 60})
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

BASE_DIR  = Path(__file__).resolve().parents[2]
OUT_BASE  = BASE_DIR / 'outputs' / 'figures'
HIST_PATH = BASE_DIR / 'data' / 'historial_modelos.csv'


class NbOutput:
    def __init__(self, notebook_name: str):
        self.nb      = notebook_name
        self.nb_dir  = OUT_BASE / notebook_name
        self.version = self._next_version()
        self.out_dir = self.nb_dir / f'v{self.version}'
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.ts      = datetime.now().strftime('%Y-%m-%d %H:%M')
        print(f'[NbOutput] {notebook_name}  →  v{self.version}  ({self.out_dir})')

    def _next_version(self) -> int:
        if not self.nb_dir.exists():
            return 1
        existing = [
            int(p.name[1:]) for p in self.nb_dir.iterdir()
            if p.is_dir() and p.name.startswith('v') and p.name[1:].isdigit()
        ]
        return max(existing, default=0) + 1

    def savefig(self, fig, name: str, dpi: int = 130):
        path = self.out_dir / f'{name}.png'
        fig.savefig(path, dpi=dpi, bbox_inches='tight')
        print(f'  [saved] {path.relative_to(BASE_DIR)}')
        return path

    def log_metrics(self, res_df: pd.DataFrame, extra: dict = None):
        """
        Append res_df (una fila por modelo) al historial global.
        Agrega columnas: notebook, version, timestamp + extra.
        """
        df = res_df.reset_index() if res_df.index.name else res_df.copy()
        df['notebook']  = self.nb
        df['version']   = self.version
        df['timestamp'] = self.ts
        if extra:
            for k, v in extra.items():
                df[k] = v

        write_header = not HIST_PATH.exists()
        df.to_csv(HIST_PATH, mode='a', header=write_header, index=False)
        print(f'  [logged] {len(df)} modelos → {HIST_PATH.name}  (v{self.version})')
        return df
