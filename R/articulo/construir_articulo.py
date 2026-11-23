import re, shutil, os, zipfile, sys
from xml.sax.saxutils import escape
import tempfile
AQUI=os.path.dirname(os.path.abspath(__file__))
os.chdir(tempfile.mkdtemp())   # se trabaja en una carpeta temporal; la plantilla está junto a este script
zipfile.ZipFile(os.path.join(AQUI,'plantilla_ICALTER_2026.docx')).extractall('un')
# Datos de los autores (uno por bloque; línea 5: correo). Cámbialos aquí y vuelve a ejecutar el script.
AUTORES=[["Roberth Carlos Gonzales Mauricio",
          "Facultad de Ingeniería Estadística e Informática",
          "Universidad Nacional del Altiplano",
          "Puno, Peru",
          "73814322@est.unap.edu.pe"],
         ["Cesia Belén Gómez Flores",
          "Facultad de Ingeniería Estadística e Informática",
          "Universidad Nacional del Altiplano",
          "Puno, Peru",
          "cesiaflores@est.unap.edu.pe"]]
SRC='un'; OUT='build'; FIG=os.path.join(AQUI,'figuras')
if os.path.exists(OUT): shutil.rmtree(OUT)
shutil.copytree(SRC, OUT)
x=open(f'{OUT}/word/document.xml',encoding='utf8').read()

ORDER=[]
def cite(text):
    def f(m):
        ks=[k.strip() for k in m.group(1).split(',')]
        for k in ks:
            if k not in ORDER: ORDER.append(k)
        return ', '.join(f'[{ORDER.index(k)+1}]' for k in ks)
    return re.sub(r'\[\[([^\]]+)\]\]', f, text)
def runs(text):
    text=cite(text)
    out=[]
    for part in re.split(r'(<i>.*?</i>)', text):
        if not part: continue
        it = part.startswith('<i>')
        if it: part = part[3:-4]
        rpr = '<w:rPr><w:i/><w:iCs/></w:rPr>' if it else ''
        out.append(f'<w:r>{rpr}<w:t xml:space="preserve">{escape(part)}</w:t></w:r>')
    return ''.join(out)
def P(style, text, extra=''):
    st = f'<w:pStyle w:val="{style}"/>' if style else ''
    return f'<w:p><w:pPr>{st}{extra}</w:pPr>{runs(text)}</w:p>'
B=lambda t: P('BodyText', t)
H1=lambda t: P('Heading1', t)
H2=lambda t: P('Heading2', t)
BL=lambda t: P('bulletlist', t)
def table(title, head, rows, widths, note=None):
    grid=''.join(f'<w:gridCol w:w="{int(w*20)}"/>' for w in widths)
    def cell(t, w, style, left=False):
        jc = '<w:jc w:val="start"/>' if left else ''
        return f'<w:tc><w:tcPr><w:tcW w:w="{w}pt" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr><w:p><w:pPr><w:pStyle w:val="{style}"/>{jc}</w:pPr>{runs(t)}</w:p></w:tc>'
    tr=lambda cells, hdr=False: f'<w:tr><w:trPr><w:cantSplit/><w:trHeight w:val="240"/>{"<w:tblHeader/>" if hdr else ""}<w:jc w:val="center"/></w:trPr>{cells}</w:tr>'
    body=tr(''.join(cell(h, w, 'tablecolhead') for h, w in zip(head, widths)), True)
    for r in rows:
        body+=tr(''.join(cell(c, w, 'tablecopy', left=(i==0)) if i==0 else cell(c, w, 'tablecopy').replace('<w:pStyle w:val="tablecopy"/>','<w:pStyle w:val="tablecopy"/><w:jc w:val="center"/>') for i,(c,w) in enumerate(zip(r, widths))))
    tbl=('<w:tbl><w:tblPr><w:tblW w:w="0pt" w:type="dxa"/><w:jc w:val="center"/><w:tblBorders>'
         + ''.join(f'<w:{s} w:val="single" w:sz="2" w:space="0" w:color="auto"/>' for s in ['top','start','bottom','end','insideH','insideV'])
         + '</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblLook w:firstRow="0" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="0"/></w:tblPr>'
         + f'<w:tblGrid>{grid}</w:tblGrid>{body}</w:tbl>')
    tbl=tbl.replace('<w:p><w:pPr>', '<w:p><w:pPr><w:keepNext/>')   # la tabla no se parte entre columnas
    return P('tablehead', title, '<w:keepNext/>') + tbl + (P('tablefootnote', note) if note else '') + '<w:p><w:pPr><w:pStyle w:val="BodyText"/><w:spacing w:after="0pt"/></w:pPr></w:p>'
rels=[]; 
def figure(fname, caption, h_in, w_in=3.3):
    n=len(rels)+1; rid=f'rIdImg{n}'; rels.append((rid, fname))
    shutil.copy(os.path.join(FIG, fname), f'{OUT}/word/media/{fname}')
    cx=int(w_in*914400); cy=int(w_in*h_in/3.4*914400)
    dr=(f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/><wp:docPr id="{100+n}" name="Figure {n}"/>'
        '<a:graphic xmlns:a="http://purl.oclc.org/ooxml/drawingml/main"><a:graphicData uri="http://purl.oclc.org/ooxml/drawingml/picture">'
        f'<pic:pic xmlns:pic="http://purl.oclc.org/ooxml/drawingml/picture"><pic:nvPicPr><pic:cNvPr id="{100+n}" name="{fname}"/><pic:cNvPicPr/></pic:nvPicPr>'
        f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>')
    return f'<w:p><w:pPr><w:keepNext/><w:jc w:val="center"/></w:pPr>{dr}</w:p>' + P('figurecaption', caption)
os.makedirs(f'{OUT}/word/media', exist_ok=True)

exec(open(os.path.join(AQUI, 'contenido_en.py'), encoding='utf8').read())
REFS={
"guirkinger":"C. Guirkinger and S. R. Boucher, “Credit constraints and productivity in Peruvian agriculture,” <i>Agric. Econ.</i>, vol. 39, no. 3, pp. 295–308, 2008.",
"boucher":"S. R. Boucher, M. R. Carter, and C. Guirkinger, “Risk rationing and wealth effects in credit markets: Theory and implications for agricultural development,” <i>Amer. J. Agric. Econ.</i>, vol. 90, no. 2, pp. 409–423, 2008.",
"chen":"T. Chen and C. Guestrin, “XGBoost: A scalable tree boosting system,” in <i>Proc. 22nd ACM SIGKDD Int. Conf. Knowl. Discovery Data Mining</i>, San Francisco, CA, USA, 2016, pp. 785–794.",
"friedman":"J. H. Friedman, “Greedy function approximation: A gradient boosting machine,” <i>Ann. Statist.</i>, vol. 29, no. 5, pp. 1189–1232, 2001.",
"lundberg17":"S. M. Lundberg and S.-I. Lee, “A unified approach to interpreting model predictions,” in <i>Adv. Neural Inf. Process. Syst.</i>, vol. 30, 2017, pp. 4765–4774.",
"lundberg20":"S. M. Lundberg et al., “From local explanations to global understanding with explainable AI for trees,” <i>Nature Mach. Intell.</i>, vol. 2, no. 1, pp. 56–67, 2020.",
"inei":"Instituto Nacional de Estadística e Informática, “Encuesta Nacional Agropecuaria 2016–2025,” Lima, Peru, 2016–2025. [Online]. Available: https://proyectos.inei.gob.pe/microdatos/ (accessed Nov. 12, 2026).",
"agrobanco":"J. C. León Carrasco, “Agrobanco otorgaría créditos por S/ 420 millones este año,” <i>Agraria.pe</i>, Feb. 25, 2019. [Online]. Available: https://www.agraria.pe/noticias/agrobanco-otorgaria-creditos-por-s-420-millones-este-ano-18484",
"friedman10":"J. Friedman, T. Hastie, and R. Tibshirani, “Regularization paths for generalized linear models via coordinate descent,” <i>J. Statist. Softw.</i>, vol. 33, no. 1, pp. 1–22, 2010.",
"wright":"M. N. Wright and A. Ziegler, “ranger: A fast implementation of random forests for high dimensional data in C++ and R,” <i>J. Statist. Softw.</i>, vol. 77, no. 1, pp. 1–17, 2017.",
"wood":"S. N. Wood, <i>Generalized Additive Models: An Introduction with R</i>, 2nd ed. Boca Raton, FL, USA: CRC Press, 2017.",
"zeileis":"A. Zeileis, “Econometric computing with HC and HAC covariance matrix estimators,” <i>J. Statist. Softw.</i>, vol. 11, no. 10, pp. 1–17, 2004.",
"hastie":"T. Hastie, R. Tibshirani, and J. Friedman, <i>The Elements of Statistical Learning</i>, 2nd ed. New York, NY, USA: Springer, 2009.",
"kuhn":"M. Kuhn, “Building predictive models in R using the caret package,” <i>J. Statist. Softw.</i>, vol. 28, no. 5, pp. 1–26, 2008.",
"saito":"T. Saito and M. Rehmsmeier, “The precision-recall plot is more informative than the ROC plot when evaluating binary classifiers on imbalanced datasets,” <i>PLoS ONE</i>, vol. 10, no. 3, Art. no. e0118432, 2015.",
"chicco":"D. Chicco and G. Jurman, “The advantages of the Matthews correlation coefficient (MCC) over F1 score and accuracy in binary classification evaluation,” <i>BMC Genomics</i>, vol. 21, Art. no. 6, 2020.",
"ludecke":"D. Lüdecke, M. S. Ben-Shachar, I. Patil, P. Waggoner, and D. Makowski, “performance: An R package for assessment, comparison and testing of statistical models,” <i>J. Open Source Softw.</i>, vol. 6, no. 60, Art. no. 3139, 2021.",
"wickham":"H. Wickham et al., “Welcome to the tidyverse,” <i>J. Open Source Softw.</i>, vol. 4, no. 43, Art. no. 1686, 2019.",
"wiener":"H. C. Wiener Fresco, “Perú: un mercado incompleto de servicios financieros al agro,” <i>Pensamiento Crítico</i>, vol. 26, no. 1, pp. 5–38, 2021, doi: 10.15381/pc.v26i1.20222.",
"ramos24":"R. Ramos-Sandoval and C. Mendiburu-Díaz, “Why do small farmers have less access to credit? A microdata analysis of the Peruvian case,” <i>Nativa</i>, vol. 12, no. 2, pp. 215–225, 2024, doi: 10.31413/nativa.v12i2.16758.",
"ramos26":"R. Ramos-Sandoval, A. Blázquez-Soriano, J. Campos-Trigoso, and Y. F. Yarango-Alcocer, “An analysis of personal and managerial characteristics of Peruvian smallholders as an alternative approach to improve their financial inclusion,” <i>Nativa</i>, vol. 14, no. 2, Art. no. e20425, 2026, doi: 10.31413/nat.v14i2.20425.",
"quispe":"J. C. Quispe Mamani et al., “Determinants of financial inclusion in households in Peru,” <i>Front. Sociol.</i>, vol. 9, Art. no. 1196651, 2024, doi: 10.3389/fsoc.2024.1196651.",
"paredes":"E. Paredes and J. Pineda, “Impact of productive associations in credit demand in small coffee farmers in Peru,” in <i>Proc. LACCEI Int. Multi-Conf. Eng., Educ. Technol.</i>, 2026, doi: 10.18687/LACCEI2026.1.1.2323.",
"ifft":"J. Ifft, R. Kuhns, and K. Patrick, “Can machine learning improve prediction – an application with farm survey data,” <i>Int. Food Agribus. Manag. Rev.</i>, vol. 21, no. 8, pp. 1083–1098, 2018, doi: 10.22434/IFAMR2017.0098.",
"maehara":"R. Maehara, L. Benites, A. Talavera, A. Aybar-Flores, and M. Muñoz, “Predicting financial inclusion in Peru: Application of machine learning algorithms,” <i>J. Risk Financial Manag.</i>, vol. 17, no. 1, Art. no. 34, 2024, doi: 10.3390/jrfm17010034.",
"condori21":"H. I. Condori-Alejo, M. R. Aceituno-Rojo, and G. Sotomayor Alzamora, “Rural micro credit assessment using machine learning in a Peruvian microfinance institution,” <i>Procedia Comput. Sci.</i>, vol. 187, pp. 408–413, 2021, doi: 10.1016/j.procs.2021.04.117.",
"condori22":"G. Sotomayor Alzamora, M. R. Aceituno-Rojo, and H. I. Condori-Alejo, “An assertive machine learning model for rural micro credit assessment in Peru,” <i>Procedia Comput. Sci.</i>, vol. 202, pp. 301–306, 2022, doi: 10.1016/j.procs.2022.04.040.",
"liu":"Z. Liu, Y. Weng, L. Zhou, and X. Xu, “Prediction of rural household credit constraints and identification of key factors based on interpretable machine learning,” in <i>Proc. 2nd Int. Conf. Artif. Intell. Digit. Finance (AIDF)</i>, Wuhan, China, 2026, doi: 10.1145/3844275.3844333.",
"jonnalagadda":"A. K. Jonnalagadda, M. V. A. L. Narasimha Rao, and S. Ramesh Babu, “Thin-file, not signal-free: An alternative-data credit score for smallholder farmers built with explainable machine learning,” <i>Int. Res. J. Multidiscip. Scope</i>, vol. 7, no. 4, pp. 1505–1520, 2026, doi: 10.47857/irjms.2026.v07i04.013934.",
"liliu":"L. Li and Q. Liu, “Analyzing financial inclusion with explainable machine learning: Evidence from an emerging economy,” <i>J. Digit. Econ.</i>, vol. 3, pp. 275–287, 2024, doi: 10.1016/j.jdec.2025.05.004.",
"pinit":"P. Pinitjitsamut and W. Suwanprasert, “Predicting informal loans using machine learning algorithms,” <i>Thailand World Econ.</i>, vol. 44, no. 3, Art. no. e278817, 2026.",
"lepenioti":"K. Lepenioti, A. Bousdekis, D. Apostolou, and G. Mentzas, “Prescriptive analytics: Literature review and research challenges,” <i>Int. J. Inf. Manage.</i>, vol. 50, pp. 57–70, 2020, doi: 10.1016/j.ijinfomgt.2019.04.003.",
"aiken":"E. Aiken, S. Bellue, D. Karlan, C. Udry, and J. E. Blumenstock, “Machine learning and phone data can improve targeting of humanitarian aid,” <i>Nature</i>, vol. 603, pp. 864–870, 2022, doi: 10.1038/s41586-022-04484-9.",
"kapoor":"S. Kapoor and A. Narayanan, “Leakage and the reproducibility crisis in machine-learning-based science,” <i>Patterns</i>, vol. 4, no. 9, Art. no. 100804, 2023, doi: 10.1016/j.patter.2023.100804.",
"ploton":"P. Ploton et al., “Spatial validation reveals poor predictive performance of large-scale ecological mapping models,” <i>Nature Commun.</i>, vol. 11, Art. no. 4540, 2020, doi: 10.1038/s41467-020-18321-y.",
"kehinde":"A. D. Kehinde and A. A. Ogundeji, “The simultaneous impact of access to credit and cooperative services on cocoa productivity in South-western Nigeria,” <i>Agric. Food Secur.</i>, vol. 11, Art. no. 11, 2022, doi: 10.1186/s40066-021-00351-4.",
"rudin":"C. Rudin, “Stop explaining black box machine learning models for high stakes decisions and use interpretable models instead,” <i>Nature Mach. Intell.</i>, vol. 1, no. 5, pp. 206–215, 2019.",
"molnar":"C. Molnar et al., “General pitfalls of model-agnostic interpretation methods for machine learning models,” in <i>xxAI – Beyond Explainable AI</i>, Lecture Notes in Computer Science, vol. 13200. Cham, Switzerland: Springer, 2022, pp. 39–68.",
"murdoch":"W. J. Murdoch, C. Singh, K. Kumbier, R. Abbasi-Asl, and B. Yu, “Definitions, methods, and applications in interpretable machine learning,” <i>Proc. Nat. Acad. Sci. USA</i>, vol. 116, no. 44, pp. 22071–22080, 2019.",
"wager":"S. Wager and S. Athey, “Estimation and inference of heterogeneous treatment effects using random forests,” <i>J. Amer. Statist. Assoc.</i>, vol. 113, no. 523, pp. 1228–1242, 2018.",
}
assert set(ORDER)==set(REFS), (set(ORDER)^set(REFS))
REFS=[REFS[k] for k in ORDER]
for r in REFS: c.append(P('references', r, '<w:ind w:start="17.70pt" w:hanging="17.70pt"/>'))

# --- ensamblar
ps=list(re.finditer(r'<w:p[ >].*?</w:p>', x, flags=re.S))
abs_p=[m for m in ps if '<w:pStyle w:val="Abstract"/>' in m.group(0)][0]
last=[m for m in ps if 'IEEE conference templates contain' in m.group(0)][0]
sect2=re.search(r'<w:sectPr.*?</w:sectPr>', x[last.start():], flags=re.S).group(0)
assert 'w:num="2"' in sect2
end_p=f'<w:p><w:pPr><w:pStyle w:val="BodyText"/>{sect2}</w:pPr></w:p>'
final_sect=x[x.rindex('<w:sectPr'):]
head=x[:abs_p.start()]
# título y nota de subtítulos
tp=[m for m in ps if '<w:pStyle w:val="papertitle"/>' in m.group(0)][0].group(0)
newt=re.sub(r'(</w:pPr>).*', r'\1', tp, flags=re.S)+f'<w:r><w:rPr><w:kern w:val="48"/></w:rPr><w:t>{escape(TITLE)}</w:t></w:r></w:p>'
head=head.replace(tp, newt)
note=[m for m in ps if 'Sub-titles are not captured' in m.group(0)][0].group(0)
assert '<w:sectPr' not in note; head=head.replace(note, '')
# autores: bloques lado a lado en una tabla sin bordes, una celda por autor (reemplaza los seis marcadores de la plantilla)
hp=list(re.finditer(r'<w:p[ >].*?</w:p>', head, flags=re.S))
a0=[m for m in hp if 'Given Name Surname' in m.group(0)][0].start()
a1=[m for m in hp if 'w:num="3"' in m.group(0)][-1].end()
def _ar(t, it=False, br=True):
    return f'<w:r><w:rPr>{"<w:i/>" if it else ""}<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>{"<w:br/>" if br else ""}<w:t xml:space="preserve">{escape(t)}</w:t></w:r>'
_ancho=int(10063/len(AUTORES))   # ancho útil de la página (twips) repartido entre autores
_sinborde=''.join(f'<w:{b} w:val="nil"/>' for b in ('top','left','bottom','right','insideH','insideV'))
autor=(f'<w:tbl><w:tblPr><w:tblW w:w="{_ancho*len(AUTORES)}" w:type="dxa"/><w:jc w:val="center"/>'
       f'<w:tblBorders>{_sinborde}</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>'
       '<w:tblGrid>' + ''.join(f'<w:gridCol w:w="{_ancho}"/>' for _ in AUTORES) + '</w:tblGrid><w:tr>')
for A in AUTORES:
    autor+=(f'<w:tc><w:tcPr><w:tcW w:w="{_ancho}" w:type="dxa"/></w:tcPr>'
            '<w:p><w:pPr><w:pStyle w:val="Author"/><w:spacing w:before="5pt" w:after="14pt"/></w:pPr>'
            + _ar(A[0], br=False) + _ar(A[1], it=True) + ''.join(_ar(t) for t in A[2:]) + '</w:p></w:tc>')
autor+=('</w:tr></w:tbl>'
        '<w:p><w:pPr><w:pStyle w:val="Author"/><w:sectPr><w:type w:val="continuous"/><w:pgSz w:w="595.30pt" w:h="841.90pt" w:code="9"/>'
        '<w:pgMar w:top="22.50pt" w:right="44.65pt" w:bottom="72pt" w:left="44.65pt" w:header="36pt" w:footer="36pt" w:gutter="0pt"/>'
        '<w:cols w:space="36pt"/><w:docGrid w:linePitch="360"/></w:sectPr></w:pPr></w:p>')
head=head[:a0]+autor+head[a1:]
open(f'{OUT}/word/document.xml','w',encoding='utf8').write(head+''.join(c)+end_p+final_sect)
# relaciones y tipos
rp=f'{OUT}/word/_rels/document.xml.rels'; r=open(rp).read()
r=r.replace('</Relationships>', ''.join(f'<Relationship Id="{i}" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/image" Target="media/{f}"/>' for i,f in rels)+'</Relationships>')
r=re.sub(r'<Relationship Id="rId(9|10)"[^>]*/>', '', r); open(rp,'w').write(r)
cp=f'{OUT}/[Content_Types].xml'; t=open(cp).read()
if 'Extension="png"' not in t: t=t.replace('<Default Extension="xml"', '<Default Extension="png" ContentType="image/png"/><Default Extension="xml"')
open(cp,'w').write(t)
dst=os.path.abspath(sys.argv[1]) if len(sys.argv)>1 else os.path.join(AQUI,'articulo_ICALTER_2026.docx')
if os.path.exists(dst): os.remove(dst)
z=zipfile.ZipFile(dst,'w',zipfile.ZIP_DEFLATED)
for root,_,files in os.walk(OUT):
    for f in sorted(files, key=lambda n: n!='[Content_Types].xml'):
        full=os.path.join(root,f); z.write(full, os.path.relpath(full,OUT))
z.close(); print('ok', dst, 'words', len(re.sub(r'<[^>]+>',' ',''.join(c)).split()))
