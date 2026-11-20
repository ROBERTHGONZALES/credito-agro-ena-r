import re, shutil, os, zipfile, sys
from xml.sax.saxutils import escape
import tempfile
AQUI=os.path.dirname(os.path.abspath(__file__))
os.chdir(tempfile.mkdtemp())   # se trabaja en una carpeta temporal; la plantilla está junto a este script
zipfile.ZipFile(os.path.join(AQUI,'plantilla_ICALTER_2026.docx')).extractall('un')
# Datos del autor (línea 5: correo; cámbialo aquí y vuelve a ejecutar el script)
AUTOR=["Roberth Carlos Gonzales Mauricio",
       "Facultad de Ingeniería Estadística e Informática",
       "Universidad Nacional del Altiplano",
       "Puno, Peru",
       "73814322@est.unap.edu.pe"]
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
    return P('tablehead', title) + tbl + (P('tablefootnote', note) if note else '') + '<w:p><w:pPr><w:pStyle w:val="BodyText"/><w:spacing w:after="0pt"/></w:pPr></w:p>'
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

TITLE="Prescriptive Analysis of Agricultural Credit Access in Peru Using Gradient Boosting and Explainable Machine Learning"
c=[]
c.append('<w:p><w:pPr><w:pStyle w:val="Abstract"/><w:rPr><w:i/><w:iCs/></w:rPr></w:pPr><w:r><w:rPr><w:i/><w:iCs/></w:rPr><w:t>Abstract</w:t></w:r><w:r><w:t xml:space="preserve">—'
 + escape("Only about one in ten small and medium agricultural producers in Peru obtains credit. We build a classification model of credit access and use it to indicate which producers to target first and which actions would raise access the most. The data are 49,837 producers from seven rounds of the National Agricultural Survey collected between 2016 and 2025, with training and test sets separated by sampling cluster. Fourteen predictors were selected from 35 candidates through cross-validated SHAP importance, removal of redundant variables and the one-standard-error rule. An XGBoost model tuned with grouped five-fold cross-validation in R reached an area under the ROC curve of 0.798 and an area under the precision-recall curve of 0.367 on the test set, three times the chance level, with well-calibrated probabilities. When producers are ranked by predicted probability, the top 20 percent contains 54 percent of all credit holders. A further 16.4 percent of producers have no credit although their profile matches that of credit holders; this unmet potential demand is concentrated on the coast. In the simulated scenarios, association membership has the largest effect and raises the estimated access rate from 12.3 to 18.7 percent, and combining it with market access, irrigation and fertilizer use doubles the rate to 25.1 percent. The complementary actions differ by region: irrigation and inputs matter most in the rainforest and market access in the highlands.")
 + '</w:t></w:r></w:p>')
c.append(P('Keywords', "Keywords—agricultural credit, financial inclusion, XGBoost, SHAP, prescriptive analytics, survey data"))

c.append(H1("Introduction"))
c.append(B("Access to credit allows agricultural producers to buy inputs, adopt technology and absorb shocks, yet formal credit reaches only a minority of small farms in developing countries. In Peru, the penetration of financial services in agriculture has remained low for decades, and the agrarian credit market has been described as incomplete [[wiener]]. Studies based on household data have shown that credit constraints lower farm productivity and that many producers who could qualify for a loan do not apply because of the risk involved [[guirkinger,boucher]]. Lenders and public programs that promote rural financial inclusion therefore need to know which producers are most likely to obtain credit and under which conditions."))
c.append(B("Most empirical work on this topic is explanatory. With the National Agricultural Survey for 2015 to 2019, farm size turned out to be a main determinant: being a smallholder reduces the probability of access to credit [[ramos24]]. Personal and managerial characteristics of smallholders also shape their financial behaviour [[ramos26]], and socioeconomic factors determine the financial inclusion of Peruvian households in general [[quispe]]. Using census data and propensity score matching, small coffee farmers who belong to an association were found to have more than twice the odds of requesting credit [[paredes]]."))
c.append(B("Machine learning adds prediction. Gradient boosting models capture nonlinear relations and interactions in tabular data [[chen,friedman]], and explanation methods such as SHAP make their predictions interpretable [[lundberg17,lundberg20]]. With farm survey data from the United States, several machine learning models predicted the demand for new credit better than standard econometric approaches, although not in every case [[ifft]]. In Peru, machine learning has been used to predict the financial inclusion of the general population [[maehara]] and to assess rural microcredit applications in a microfinance institution [[condori21,condori22]]. Interpretable gradient boosting has also been applied to identify credit-constrained rural households in China [[liu]], to score smallholder farmers in India [[jonnalagadda]], and to study financial inclusion [[liliu]] and informal borrowing [[pinit]]."))
c.append(B("None of these studies uses the model to recommend actions, which is what we do here. Prescriptive analytics seeks the best course of action and is considered the next level of maturity after descriptive and predictive analytics [[lepenioti]]. In development policy, one example is the use of machine learning to target social assistance [[aiken]]. To our knowledge, this approach has not been applied to agricultural credit in Peru."))
c.append(B("The paper has three parts. We first build and validate a classifier of credit access with the National Agricultural Survey (ENA, by its Spanish acronym) of Peru [[inei]], after reducing 35 candidate predictors to 14. We then measure how well the model ranks producers, since targeting depends on the ranking. Finally, we use the model to estimate the size and location of an unmet potential demand and to simulate the effect of four actionable conditions in each natural region. All the analysis was done in R."))

c.append(H1("Data and Methods"))
c.append(H2("Data"))
c.append(B("The ENA is an annual survey of agricultural producers conducted by the National Institute of Statistics and Informatics [[inei]]. The study population is small and medium producers. We used seven rounds: 2016, 2017, 2019 and 2022 to 2025. We excluded the 2014, 2015 and 2018 rounds because they lack area, experience and parcel variables. There was no survey in 2020, and the 2021 round has no credit module. The target variable equals one when the producer obtained credit in the reference period and zero otherwise."))
c.append(B("The modeling sample has 49,837 producers (Table I). We split it into training and test sets by sampling cluster, so no cluster contributes to both sets. Neighbors share local conditions, and a split that ignores this dependence leaks information and gives overoptimistic results [[kapoor,ploton]]. Credit holders are 11.9 percent of the sample. With survey weights the national rate is 10.1 percent: 20.4 percent on the coast, 12.7 percent in the rainforest and 7.5 percent in the highlands."))
c.append(table("Modeling Sample", ["Set","Producers","Clusters","With credit","Rate (%)"],
   [["Training","39,868","6,005","4,750","11.9"],["Test","9,969","1,486","1,187","11.9"],["Total","49,837","7,491","5,937","11.9"]], [56,50,46,52,40]))
c.append(H2("Variable Selection"))
c.append(B("Thirty-five candidate predictors describe the producer (age, education, household size), the farm (areas, parcels, irrigation, livestock), practices (fertilizers, pesticides, technical assistance), market links (share of crops sold, sales destination), organization (association membership) and location (natural region and department). We selected variables in three steps, using only the training set."))
c.append(BL("Importance. We fitted an XGBoost model with five-fold cross-validation grouped by cluster and ranked each variable by its mean absolute SHAP value [[lundberg17]] on the held-out folds."))
c.append(BL("Redundancy. For every pair of variables with an absolute Spearman correlation of 0.70 or more, we kept only the more important one. This removed five variables, among them years of experience, which is correlated with age (0.72)."))
c.append(BL("Parsimony. We refitted the model with the k most important variables for increasing k and chose the smallest k whose cross-validated performance lies within one standard error of the best [[hastie]]."))
c.append(H2("Model Training and Evaluation"))
c.append(B("The classifier is XGBoost [[chen]] trained through the caret package [[kuhn]]. Nine hyperparameters (number of trees, learning rate, tree depth, minimum child weight, row and column subsampling, and three regularization terms) were tuned by random search over 40 combinations, each evaluated with the same grouped five-fold cross-validation. The selection metric was the area under the precision-recall curve (AUC-PR), which is more informative than the ROC curve when the positive class is rare [[saito]]. We did not resample to correct class imbalance, because resampling before the data are split inflates performance [[jonnalagadda]]; the imbalance is handled by the metric and the threshold. The threshold is the value that maximizes the F1 score on the out-of-fold predictions. We used the test set once, after all choices had been made."))
c.append(B("We report the area under the ROC curve (AUC-ROC), AUC-PR, the Matthews correlation coefficient (MCC) [[chicco]], recall, precision, specificity and the Brier score. As a transparent benchmark, we fitted a logistic regression with the same predictors and examined it with the easystats packages [[ludecke]], which provide odds ratios, collinearity checks and goodness-of-fit measures. Data handling and graphics used the tidyverse [[wickham]]."))
c.append(H2("Prescriptive Analysis"))
c.append(B("We ran three exercises with the final model on the test set. For targeting, we ranked producers by predicted probability and computed the share of credit holders captured at each coverage level. For potential demand, we identified producers without credit whose predicted probability is at or above the classification threshold; according to the model, their profile is the same as that of credit holders. For the scenarios, we switched on one actionable condition only for the producers who lack it, kept every other variable unchanged, and recomputed the mean predicted probability. The four conditions are association membership, sales to regional or Lima markets, irrigation on all crops and fertilizer use."))

c.append(H1("Results"))
c.append(H2("Selected Variables and Predictive Performance"))
c.append(B("Cross-validated AUC-PR peaks at 0.347 with 20 variables and is 0.340 with 14, within one standard error, so we kept 14 variables. All 35 candidates together give 0.348, so the 21 discarded variables add almost nothing. The best configuration has 604 trees, a learning rate of 0.0235 and a depth of 6; its cross-validated AUC-PR is 0.349 (standard deviation 0.025) and its AUC-ROC is 0.790 (0.008). The F1-optimal threshold is 0.175."))
c.append(table("Test Set Performance (9,969 Producers)", ["Metric","XGBoost","Logistic","Chance"],
   [["AUC-ROC","0.798","0.791","0.500"],["AUC-PR","0.367","0.359","0.119"],["MCC","0.307","0.308","0.000"],["F1 score","0.396","0.400","0.000"],["Recall","0.588","0.524","0.000"],
    ["Precision","0.299","0.323","0.000"],["Specificity","0.814","0.852","1.000"],["Brier score","0.089","0.090","0.105"]], [70,56,56,56],
   "Chance: a classifier that assigns every producer to the majority class."))
c.append(B("On the test set (Table II), XGBoost reaches an AUC-ROC of 0.798 and an AUC-PR of 0.367, three times the chance level of 0.119. It identifies 698 of the 1,187 credit holders (59 percent) and 7,146 of the 8,782 producers without credit (81 percent). Probabilities are well calibrated: in the top decile the mean predicted probability is 42.0 percent and the observed rate is 42.7 percent. Performance is stable across years (AUC-ROC from 0.754 to 0.827) and regions (0.761 to 0.787), and the training AUC-ROC of 0.823 is close to the test value, so overfitting is limited. The logistic regression is close to XGBoost on ranking metrics, while XGBoost has higher recall. The AUC-ROC is within the range reported for comparable problems with survey data, such as 0.783 for credit access among smallholders in India [[jonnalagadda]] and 0.652 for credit constraints of rural households in China [[liu]]."))
c.append(H2("Factors Associated with Credit"))
c.append(B("Fig. 1 ranks the 14 variables by mean absolute SHAP value. Harvested area is the most important, followed by age, department, household size and fertilizer use. In terms of predicted probability, association membership adds 7.1 percentage points, moving from 0.27 to 2.43 harvested hectares (first to third quartile) adds 6.0, fertilizer use adds 4.1, and moving from 45 to 65 years of age subtracts 2.6."))
c.append(figure('fig1_shap.png', "Importance of the 14 selected variables (mean absolute SHAP value, test set).", 2.7))
c.append(B("The logistic regression gives the same direction for these effects. Association members have twice the odds of holding credit (odds ratio 2.12; 95 percent confidence interval 1.92 to 2.34). The odds also increase with harvested area (1.64 per log unit), fertilizer use (1.62), land renting (1.51) and pesticide use (1.41), and decrease with age (0.83 per ten years) and for producers in the highlands (0.66) and the rainforest (0.75) relative to the coast. Tjur's coefficient of determination is 0.134. The odds ratio for association membership agrees with the estimate of more than two obtained with census data for small coffee farmers [[paredes]], and the weight of harvested area agrees with the role of farm size reported for Peru [[ramos24]]."))
c.append(H2("Targeting"))
c.append(B("Fig. 2 shows the cumulative gain curve. Serving the 10 percent of producers with the highest predicted probability reaches 36 percent of all credit holders; 20 percent of producers reaches 54 percent and 30 percent reaches 67 percent. In the top decile, 43 of every 100 producers hold credit, 3.6 times the rate of a random selection."))
c.append(figure('fig2_gain.png', "Cumulative gain: share of credit holders captured by coverage level. The dashed line is a random selection.", 2.4))
c.append(H2("Unmet Potential Demand"))
c.append(B("Of the 9,969 test producers, 1,636 (16.4 percent) have no credit although the model assigns them a probability at or above the threshold. Table III compares them with credit holders and with the remaining producers. The potential group harvests more than three hectares, almost nine in ten use fertilizers and more than half already sell to regional markets; the rest harvest about half a hectare and are six years older on average. The share of potential demand is highest in Tumbes (45 percent of its producers), Tacna (36), Lambayeque (33), Ica (27) and Madre de Dios (26), and lowest in Loreto (1), Ancash (3), Huancavelica (5) and Huanuco (6)."))
c.append(table("Profile of Producer Groups (Test Set)", ["Characteristic","With credit","Potential","Rest"],
   [["Producers","1,187","1,636","7,146"],["Harvested area, median (ha)","2.50","3.16","0.55"],["Mean age (years)","50.4","50.4","56.3"],["Association members (%)","15.1","19.6","2.7"],
    ["Use fertilizers (%)","79.8","88.1","47.2"],["Sell to regional markets (%)","50.5","53.9","18.0"],["Irrigated crops (%)","59.5","61.8","38.0"],["Located on the coast (%)","40.4","44.4","12.6"],["Located in the highlands (%)","39.3","30.7","66.7"]],
   [112,46,44,40], "Potential: no credit and predicted probability at or above the threshold. Rest: no credit and probability below it."))
c.append(H2("Scenario Simulation"))
c.append(B("The mean predicted access rate in the test set is 12.3 percent. Table IV reports how it would change if the producers who lack each condition had it, and Fig. 3 gives the result by region. Association membership has the largest effect in the three regions and would raise the national rate to 18.7 percent; 93 percent of producers are not members. Irrigation adds 1.5 points nationally but 3.6 in the rainforest, where 97 percent of producers do not irrigate all their crops. Market sales add 1.2 points, with the largest effect in the highlands, where 81 percent of producers do not reach regional markets. Combining association and market access raises the rate to 20.3 percent, and the four conditions together to 25.1 percent; in the rainforest the rate would go from 13.1 to 32.3 percent."))
c.append(table("Simulated National Access Rate by Scenario", ["Scenario","Lacking it (%)","Rate (%)","Gain (pp)"],
   [["Baseline","n/a","12.3","n/a"],["Association membership","93.1","18.7","6.4"],["Irrigation on all crops","62.7","13.8","1.5"],["Regional/Lima market sales","72.3","13.5","1.2"],
    ["Fertilizer use","42.2","13.4","1.2"],["Association + market","97.3","20.3","8.0"],["All four conditions","98.9","25.1","12.8"]], [104,52,42,44],
   "pp: percentage points. Lacking it: producers without at least one of the conditions in the scenario."))
c.append(figure('fig3_scenarios.png', "Simulated increase in the credit access rate by scenario and natural region (percentage points).", 3.3))

c.append(H1("Discussion"))
c.append(B("We derive five lines of action from these results. First, lenders and programs can use the model to focus credit promotion, because the top 20 percent of producers by predicted probability contains more than half of the effective demand. Second, the potential group should be served first, starting in Tumbes, Tacna, Lambayeque, Ica and Madre de Dios; these producers already farm like credit holders, so what they lack is an offer of credit. Third, association membership is the action with the highest return in every region, which suggests linking credit products to cooperatives and producer associations; joint access to credit and cooperative services has also been associated with higher farm productivity [[kehinde]]. Fourth, complementary actions should differ by region: irrigation and input use in the rainforest, market access in the highlands, and association on the coast, where irrigation and inputs are already widespread. Fifth, the remaining 72 percent of producers, who harvest about half a hectare, are unlikely to be reached by conventional credit and require microcredit, group guarantees and prior technical assistance."))
c.append(B("The logistic regression performs almost as well as XGBoost, so the relation between these predictors and credit is largely additive. When transparency is the priority, the simpler model is an acceptable choice for this problem. This is in line with the argument for inherently interpretable models in high-stakes decisions [[rudin]] and with evidence that machine learning does not always outperform standard models on survey data [[ifft,liu]]. Both methods give the same direction for every effect we report."))
c.append(B("The study has three limitations. The scenarios are estimates from a model fitted to observational data, so they describe association: a producer may use fertilizers because credit was obtained. Model-agnostic interpretation methods can lead to wrong conclusions when they are read causally or when features are dependent [[molnar,murdoch]]. Before any large-scale use, the scenarios should be validated with pilot programs or with designs that estimate causal and heterogeneous effects, such as matching [[paredes]] or causal forests [[wager]]. Precision is 0.30, so the model is suitable for prioritizing groups but not for deciding individual cases. Finally, the survey records whether credit was obtained and does not record whether it was requested, so we cannot separate demand from supply constraints."))

c.append(H1("Conclusions"))
c.append(B("A gradient boosting model with 14 survey variables ranks Peruvian agricultural producers by their likelihood of holding credit with an AUC-ROC of 0.798 and well-calibrated probabilities. One fifth of producers concentrates more than half of the credit, and 16.4 percent of producers form an unmet potential demand located mainly on the coast. Association membership is the action with the largest simulated effect, and the complementary actions vary by region. Future work should add the supply side, such as the distance to financial institutions, and evaluate the proposed actions with experimental or quasi-experimental designs."))

c.append(P('Heading5', "Data and Code Availability"))
c.append(B("The modeling sample of 49,837 producers, the R scripts, the result tables and the figures are available at github.com/ROBERTHGONZALES/credito-agro-ena-r. The repository reproduces every result in this paper from the cleaned sample. The original ENA microdata are published by the National Institute of Statistics and Informatics [[inei]]."))
c.append(P('Heading5', "Acknowledgment"))
c.append(B("The author thanks the National Institute of Statistics and Informatics of Peru for making the survey microdata publicly available."))
c.append(P('Heading5', "References"))
REFS={
"guirkinger":"C. Guirkinger and S. R. Boucher, “Credit constraints and productivity in Peruvian agriculture,” <i>Agric. Econ.</i>, vol. 39, no. 3, pp. 295–308, 2008.",
"boucher":"S. R. Boucher, M. R. Carter, and C. Guirkinger, “Risk rationing and wealth effects in credit markets: Theory and implications for agricultural development,” <i>Amer. J. Agric. Econ.</i>, vol. 90, no. 2, pp. 409–423, 2008.",
"chen":"T. Chen and C. Guestrin, “XGBoost: A scalable tree boosting system,” in <i>Proc. 22nd ACM SIGKDD Int. Conf. Knowl. Discovery Data Mining</i>, San Francisco, CA, USA, 2016, pp. 785–794.",
"friedman":"J. H. Friedman, “Greedy function approximation: A gradient boosting machine,” <i>Ann. Statist.</i>, vol. 29, no. 5, pp. 1189–1232, 2001.",
"lundberg17":"S. M. Lundberg and S.-I. Lee, “A unified approach to interpreting model predictions,” in <i>Adv. Neural Inf. Process. Syst.</i>, vol. 30, 2017, pp. 4765–4774.",
"lundberg20":"S. M. Lundberg et al., “From local explanations to global understanding with explainable AI for trees,” <i>Nature Mach. Intell.</i>, vol. 2, no. 1, pp. 56–67, 2020.",
"inei":"Instituto Nacional de Estadística e Informática, “Encuesta Nacional Agropecuaria,” Lima, Peru. [Online]. Available: https://proyectos.inei.gob.pe/microdatos/",
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
# autor: un solo bloque centrado a una columna (reemplaza los seis marcadores de la plantilla)
hp=list(re.finditer(r'<w:p[ >].*?</w:p>', head, flags=re.S))
a0=[m for m in hp if 'Given Name Surname' in m.group(0)][0].start()
a1=[m for m in hp if 'w:num="3"' in m.group(0)][-1].end()
def _ar(t, it=False, br=True):
    return f'<w:r><w:rPr>{"<w:i/>" if it else ""}<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>{"<w:br/>" if br else ""}<w:t xml:space="preserve">{escape(t)}</w:t></w:r>'
autor=('<w:p><w:pPr><w:pStyle w:val="Author"/><w:spacing w:before="5pt" w:beforeAutospacing="1"/></w:pPr>'
       + _ar(AUTOR[0], br=False) + _ar(AUTOR[1], it=True) + ''.join(_ar(t) for t in AUTOR[2:]) + '</w:p>'
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
