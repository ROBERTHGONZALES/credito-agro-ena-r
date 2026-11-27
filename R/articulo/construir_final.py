"""Arma la versión final para ICALTER 2026 (camera-ready): articulo_ICALTER_2026_final.docx.

Reutiliza construir_articulo.py (plantilla, tablas, figuras y referencias) y solo cambia:
  - el texto, que está en contenido_final.py (inglés, 4 a 6 páginas, respuesta a los revisores);
  - los autores: uno solo, como en el envío original (ICALTER no permite cambiar la lista de autores);
  - la afiliación: Escuela Profesional (requisito del reglamento de titulación por artículo de la UNA Puno);
  - las referencias: solo las que se citan.
Uso, desde la carpeta AGRO:  python3 R/articulo/construir_final.py
PDF:  soffice --headless --convert-to pdf --outdir R/articulo R/articulo/articulo_ICALTER_2026_final.docx
"""
import os, re

AQUI = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(AQUI, 'construir_articulo.py'), encoding='utf8').read()

i0 = src.index('AUTORES=['); i1 = src.index("SRC='un'")
src = src[:i0] + '''AUTORES=[["Roberth Carlos Gonzales Mauricio",
          "Escuela Profesional de Ingeniería Estadística e Informática",
          "Universidad Nacional del Altiplano",
          "Puno, Peru",
          "73814322@est.unap.edu.pe"]]
''' + src[i1:]
for viejo, nuevo in [("'contenido_en.py'", "'contenido_final.py'"),
                     ("'articulo_ICALTER_2026.docx'", "'articulo_ICALTER_2026_final.docx'"),
                     ("assert set(ORDER)==set(REFS), (set(ORDER)^set(REFS))", "assert set(ORDER)<=set(REFS), (set(ORDER)-set(REFS))")]:
    assert src.count(viejo) == 1, viejo
    src = src.replace(viejo, nuevo)

# Aviso de copyright que indica ICALTER 2026 ("PDF Instructions for Authors"): pie de la primera página.
gancho = "dst=os.path.abspath(sys.argv[1])"
assert src.count(gancho) == 1
src = src.replace(gancho, '''_p = f'{OUT}/word/footer1.xml'; _t = open(_p, encoding='utf8').read()
_a = 'XXX-X-XXXX-XXXX-X/XX/$XX.00 ©20XX IEEE'; assert _a in _t
open(_p, 'w', encoding='utf8').write(_t.replace(_a, '979-8-3195-6750-5/26/$31.00 ©2026 IEEE'))
''' + gancho)

exec(compile(src, 'construir_articulo.py (final)', 'exec'))
