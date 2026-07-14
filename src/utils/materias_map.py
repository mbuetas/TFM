"""
Mapeo de materias y niveles educativos — TFM V11.

Se mantiene el esquema de bloques temáticos de V9, pero con reglas ampliadas y
limpias para cubrir las 127 materias del dataset V11 (2010-2020, escuela catalana,
nombres en catalán/castellano + materias IB).

Bloques (groupings para explicabilidad):
  LING — Lingüístico   : lengua materna (cat/cas), extranjera (ing/fr/al), clásica (latín)
  STEM — Ciencia/Tec   : matemáticas, ciencias nat., física/química/biología, tecnología, informática
  SOC  — Sociocultural : sociales, historia, filosofía, arte, música, plástica, educación física
  PERS — Personal      : religión, valores éticos, economía, proyectos/recerca, salud, tutoría
  ACT  — Actitudinal   : observaciones / "Final" / no académicas → SE EXCLUYE del modelo

Uso:
    from src.utils.materias_map import asignar_bloque, normalizar_nivel
    notas['bloque'] = notas['NombreAsignatura'].apply(asignar_bloque)
    notas['nivel']  = notas['NivEstudio'].apply(normalizar_nivel)

Las features del modelo se construyen por bloque (nota_media__STEM, pct_aprobado__LING…)
Y EN PARALELO por materia individual (mat__Matematiques…) para explicabilidad.
"""
import re
import unicodedata

BLOQUES = ['LING', 'STEM', 'SOC', 'PERS']   # ACT se excluye del modelo


def normalize(s):
    """minúsculas + sin tildes + espacios colapsados."""
    if not isinstance(s, str):
        return ''
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    return re.sub(r'\s+', ' ', s).lower().strip()


# ── Reglas (patrón regex sobre nombre normalizado, bloque). Primera gana. ──────
# ORDEN: ACT → LING → SOC(arte/EF/social) → STEM → PERS.
# SOC va antes que STEM para que "educacio fisica" no caiga en STEM por "fisica".
REGLAS = [
    # ── ACT — no académicas / resúmenes (la mayoría ya filtradas por SQL) ─────
    (r'^final$|^nota$|^t[12]$|\bagenda\b|\bmenjador\b|\bactitud|\bnormas\b'
     r'|responsabilit|\bescacs\b|cura dels treballs|atencio i concentracio'
     r'|relacio amb companys|saber relacionar|adapataci|\badaptacio\b'
     r'|global \(obs|\btutoria\b|dinamica de grup|habits',
     'ACT'),

    # ── LING — lenguas (materna + extranjera + clásica) ──────────────────────
    (r'llengua catalana|lengua catalana|catala i literatura'
     r'|llengua castellana|lengua castellana|castellana y literatura'
     r'|llengua estrangera|lengua extranjera|lengua extrangera'
     r'|\bingles\b|\bangles\b|\benglish\b|adquisicio de llengues|adquisicion de lenguas'
     r'|\bfrances\b|\bfrancais\b|\baleman\b|\balemany\b|\bdeutsch\b'
     r'|\bllati\b|\blatin\b|lengua vasca|euskera|euskara'
     r'|refuerzo lengua|reforc.* (?:catala|llengua|lengua)|ampliacio catala'
     r'|habilitat lectora|comprensio lectora|expresion escrita|comunicacio oral'
     r'|percepcio,? comprensio|\beschribir\b|\bescriure\b|\bescribir\b'
     r'|\besquemes\b|\bresums?\b|us del diccionari|\bdiccionari\b'
     r'|taller d.expressio'
     r'|\bliteratura\b|\bcastellano\b|\bcastella\b|\bgrec\b|\bgriego\b',  # +V11
     'LING'),

    # ── SOC — sociales, historia, filosofía, arte, música, ed. física ────────
    (r'ciencies socials|ciencias sociales|geografia|\bhistoria\b|historia d.espanya'
     r'|historia del mon|historia de l.art|historia de la filosofia'
     r'|individus i societats|individuos y sociedades'
     r'|\bfilosofia\b|filosofia i ciutadania|\betica\b|eticocivica|civic'
     r'|valores sociales|valors? socials|ciutadania|ciudadania'
     r'|\bmusica\b|\bmusic\b|educacio artistica|educacion artistica|\bartes?\b'
     r'|\bplastica\b|visual i plastica|educacio visual|educacion plastica'
     r'|\bdibuix\b|\bdibujo\b'
     r'|educacio fisica|educacion fisica|educacion fisicay'
     r'|psicolog|sociolog',
     'SOC'),

    # ── STEM — matemáticas, ciencias, física/química/biología, tecnología ────
    (r'matematiques|matematicas|\bmatematica\b'
     r'|coneixement del medi natural|ciencies de la naturalesa|ciencias naturales'
     r'|ciencias de la naturaleza|ciencies naturals|conocimiento del medio natural'
     r'|fisica i quimica|fisica y quimica|\bquimica\b|\bfisica\b'
     r'|\bbiologia\b|biologia (?:i|y) geologia|\bgeologia\b'
     r'|ciencies de la terra|ciencias de la tierra|medi ambient'
     r'|ciencies del mon contemporani|ciencias del mundo contemporaneo'
     r'|\btecnolog|\binformatic|\bdesign\b|\bdisseny\b|\bdiseno\b|technology'
     r'|petites investigacions|\bgeometria\b'
     r'|\bfisika\b|automatisme|automatismos',                 # +V11
     'STEM'),

    # ── PERS — religión, valores éticos, economía, proyectos, salud ──────────
    (r'religi|valores? eticos|valors? etics|\bvalors\b'
     r'|economi|empresa (?:i|en|y)|emprenedoria|emprendimiento'
     r'|treball de recerca|projecte de recerca|projecte interdisciplinar'
     r'|trabajo de sintesis|trabajo de investigacion|proyecto'
     r'|educacio per la salut|educacion para la salud'
     r'|\bhort\b',
     'PERS'),
]


def asignar_bloque(nombre):
    """NombreAsignatura → bloque temático (LING/STEM/SOC/PERS/ACT)."""
    n = normalize(nombre)
    for patron, bloque in REGLAS:
        if re.search(patron, n):
            return bloque
    return 'OTROS'   # sin clasificar → revisar y, por defecto, tratar como PERS


# ── Materia CORE — agrupa familias de asignaturas en features densas ──────────
# Problema: tomar cada asignatura por separado genera columnas ultra-dispersas y
# NO generalizables (cada centro nombra distinto sus optativas; p.ej. mat__Aleman
# = 98% nulos). Solución: agrupar en ~10 MATERIAS CORE comparables entre centros y
# niveles. Las lenguas extranjeras (Inglés/Francés/Alemán) → una sola feature;
# todas las ciencias (Naturales/Física/Química/Biología) → una; etc.
# Esto reduce nulos y da features interpretables. Las muy raras (Latín, Griego)
# devuelven None: no generan mat__ pero siguen sumando en su bloque (LING/STEM/…).
# Orden importa: Ed_Fisica antes que Ciencias (que contiene 'fisica').
CANONICAS = [
    # ── Lenguas ──────────────────────────────────────────────────────────────
    (r'llengua catalana|lengua catalana|catala i literatura',                       'Lengua_Catalana'),
    (r'llengua castellana|lengua castellana|castellana y literatura|\bcastellano\b', 'Lengua_Castellana'),
    (r'llengua estrangera|lengua extranjera|lengua extrangera|\bingles\b|\bangles\b'
     r'|\benglish\b|adquisicio de llengues|adquisicion de lenguas'
     r'|\bfrances\b|\bfrancais\b|\baleman\b|\balemany\b|\bdeutsch\b',               'Lengua_Extranjera'),
    # ── Ed. Física (antes de Ciencias para no capturar por 'fisica') ─────────
    (r'educacio fisica|educacion fisica',                                           'Educacion_Fisica'),
    # ── Matemáticas ─────────────────────────────────────────────────────────
    (r'matematiques|matematicas|\bmatematica\b',                                    'Matematicas'),
    # ── Ciencias (naturales + física + química + biología + geología) ────────
    (r'coneixement del medi natural|ciencies de la naturalesa|ciencias naturales'
     r'|ciencias de la naturaleza|ciencies naturals|conocimiento del medio natural'
     r'|fisica i quimica|fisica y quimica|\bquimica\b|\bfisica\b|\bfisika\b'
     r'|\bbiologia\b|biologia (?:i|y) geologia|geologia'
     r'|ciencies del mon contemporani|ciencias del mundo contemporaneo',           'Ciencias'),
    # ── Tecnología + Informática ─────────────────────────────────────────────
    (r'\btecnolog|technology|\bdesign\b|\bdisseny\b|\bdiseno\b|\binformatic',       'Tecnologia'),
    # ── Ed. Artística (música + plástica + dibujo + artística) ───────────────
    (r'\bmusica\b|\bmusic\b|\bplastica\b|visual i plastica|educacio visual'
     r'|educacion plastica|\bdibuix\b|\bdibujo\b|educacio artistica|educacion artistica', 'Educacion_Artistica'),
    # ── Sociales (sociales + historia + geografía + filosofía + economía) ────
    (r'ciencies socials|ciencias sociales|geografia|\bhistoria\b|historia de la filosofia'
     r'|\bfilosofia\b|individus i societats|individuos y sociedades'
     r'|economi|empresa (?:i|en|y)|emprenedoria',                                  'Sociales'),
    # ── Religión / Valores (alternativa entre sí → densa combinada) ──────────
    (r'religi|valores? eticos|valors? etics',                                      'Religion_Valores'),
]


def canonical_materia(nombre):
    """NombreAsignatura → MATERIA CORE (o None si no es troncal frecuente)."""
    n = normalize(nombre)
    for patron, canon in CANONICAS:
        if re.search(patron, n):
            return canon
    return None


# ── Normalización de niveles educativos (años viejos traen variantes sucias) ──
def normalizar_nivel(niv):
    """Canonicaliza NivEstudio: Pri./Primària → Primaria, Secundària → ESO, etc."""
    n = normalize(niv)
    if not n:
        return 'Desconocido'
    if 'infantil' in n:
        return 'Infantil'
    if n.startswith('pri') or 'primaria' in n or 'primària' in n or 'primaria' in n:
        return 'Primaria'
    if 'secundaria' in n or 'secundària' in n or 'eso' in n:
        return 'ESO'
    if 'batxillerat' in n or 'bachiller' in n:   # cubre 'Bachiller' y 'Bachillerato'
        return 'Bachillerato'
    if 'cicl' in n:                              # Ciclos Formativos / Cicles Formatius
        return 'Ciclos Formativos'
    return niv.strip()


# Niveles a EXCLUIR del modelo (sin notas numéricas comparables / masa insuficiente)
NIVELES_EXCLUIDOS = ['Infantil', 'Ciclos Formativos']


if __name__ == '__main__':
    # Smoke-test con materias representativas de V11
    pruebas = [
        'Llengua Catalana i Literatura', 'Lengua castellana y literatura',
        'Llengua estrangera (Anglès)', 'Llatí', 'Alemán',
        'Matemàtiques', 'Coneixement del medi natural', 'Física y Química',
        'Tecnologia', 'DISEÑO-TECHNOLOGY', 'CIENCIAS- BIOLOGÍA',
        'Ciències socials', 'Història de la filosofia', 'Educació física',
        'Música', 'Educació visual i plàstica',
        'RELIGIÓN', 'VALORES ÉTICOS', 'Economia d\'empresa',
        'Treball de Recerca', 'Final', 'Menjador',
    ]
    for p in pruebas:
        print(f'  {asignar_bloque(p):<6} ← {p}')
