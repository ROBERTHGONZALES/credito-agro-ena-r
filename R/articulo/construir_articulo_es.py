"""Arma la versión en español del artículo: articulo_ICALTER_2026_es.docx.

Reutiliza construir_articulo.py (autores, plantilla, tablas, figuras y referencias) y solo cambia:
  - el texto, que está en contenido_es.py;
  - las figuras, que salen de figuras_es/ (script R/10_figuras_articulo_es.R);
  - los rótulos "TABLE" → "TABLA" y el idioma del documento (español de Perú).
Uso, desde la carpeta AGRO:  python3 R/articulo/construir_articulo_es.py
"""
import os, re, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(AQUI, 'construir_articulo.py'), encoding='utf8').read()

assert src.count("'contenido_en.py'") == 1
src = src.replace("'contenido_en.py'", "'contenido_es.py'")

for viejo, nuevo in [("FIG=os.path.join(AQUI,'figuras')", "FIG=os.path.join(AQUI,'figuras_es')"),
                     ("'articulo_ICALTER_2026.docx'", "'articulo_ICALTER_2026_es.docx'")]:
    assert src.count(viejo) == 1, viejo
    src = src.replace(viejo, nuevo)

# Rótulos de tabla e idioma: se ajustan justo antes de comprimir el .docx
gancho = "dst=os.path.abspath(sys.argv[1])"
assert src.count(gancho) == 1
src = src.replace(gancho, '''for _f, _a, _b in [('numbering.xml', 'w:val="TABLE %1. "', 'w:val="TABLA %1. "'),
                   ('styles.xml', 'w:lang w:val="en-US"', 'w:lang w:val="es-PE"'),
                   ('settings.xml', 'w:themeFontLang w:val="en-US"', 'w:themeFontLang w:val="es-PE"')]:
    _p = f'{OUT}/word/{_f}'; _t = open(_p, encoding='utf8').read()
    assert _a in _t, (_f, _a); open(_p, 'w', encoding='utf8').write(_t.replace(_a, _b))
''' + gancho)

exec(compile(src, 'construir_articulo.py (es)', 'exec'))
