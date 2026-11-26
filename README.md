# Acceso al crédito agrario en el Perú: focalización y análisis de escenarios con R

Material de reproducción del estudio sobre acceso al crédito agrario en el Perú, hecho íntegramente en **R**, con informes en **Quarto** y pensado para trabajarse en **Positron**.

El artículo **"Targeting Agricultural Credit Access in Peru with Gradient Boosting and Explainable Machine Learning"** fue aceptado para presentación oral en ICALTER 2026 (IEEE). La versión ampliada del estudio se titula "Agricultural Credit Access in Peru: Targeting and Scenario Analysis with Interpretable Machine Learning".

Autores del estudio: Roberth Carlos Gonzales Mauricio y Cesia Belén Gómez Flores, Facultad de Ingeniería Estadística e Informática, Universidad Nacional del Altiplano (Puno, Perú).

El estudio usa la Encuesta Nacional Agropecuaria (ENA) 2016–2025 del INEI para responder:

1. ¿Qué pequeños y medianos productores tienen más probabilidad de solicitar y obtener crédito?
2. ¿Dónde están los productores con perfil de prestatario que no piden crédito?
3. ¿Quién presta (público, municipal, privado) y qué pasó cuando cayó Agrobanco?
4. ¿Qué condiciones se asocian con un mayor acceso y a quién conviene intervenir con presupuesto limitado?

## Dashboard en línea

**[roberthgonzales.github.io/credito-agro-ena-r](https://roberthgonzales.github.io/credito-agro-ena-r/)**: mapa del Perú, ficha de cada uno de los 24 departamentos (acceso, solicitud, brecha, prestamistas, perfil de productores y escenarios), comparación entre departamentos, simulador de focalización y datos descargables. Funciona en el navegador con Shinylive (la primera carga tarda unos segundos).

## Resultados principales

- **El modelo ordena bien a los productores.** En conglomerados no vistos, XGBoost logra un AUC-ROC de 0.798 (IC 95 %: 0.780–0.814). Se mantiene estable al predecir cada ronda solo con las anteriores (0.774–0.810) y con los 196,566 productores depurados (0.801). Conviene recalibrarlo en cada ronda porque sobreestima la tasa del año siguiente en 1 a 3 puntos. Un modelo aditivo, un bosque aleatorio y la regresión logística rinden casi igual (0.791–0.796).
- **El acceso depende de solicitar.** El 13.0 % de los productores pidió crédito y al 91.9 % de ellos se lo dieron.
- **Focalización.** El 20 % de productores con mayor probabilidad reúne al 54 % de quienes tienen crédito.
- **Brecha de propensión.** El 16.4 % no tiene crédito aunque el modelo le da una probabilidad alta, pero solo el 1.9 % de ellos solicitó: la barrera está antes de pedir.
- **Prestamistas.** Cuando el crédito público cayó en 2019 (crisis de Agrobanco), ningún otro prestamista lo reemplazó. El crédito público llega sobre todo a productores asociados.
- **Escenarios.** Asociarse es la condición más ligada al crédito (tasa nacional ponderada simulada de 10.3 % a 16.4 %). Son predicciones condicionales del modelo, no efectos causales.
- **Presupuesto.** Para promover la asociatividad entre 1,000 productores sin crédito: elegir por probabilidad da 106 nuevos accesos esperados frente a 64 al azar, pero concentra el programa en la costa. Elegir por ganancia simulada da 95 y lleva el 74 % del programa a la sierra y la selva.

## Contenido

| Ruta | Qué contiene |
|---|---|
| `data/etapas/09_muestra_modelo.parquet` | Muestra de modelado: 49,837 productores, 44 columnas |
| `data/etapas/08_limpio.parquet` | Los 196,566 productores depurados (comprobaciones con todos los datos) |
| `data/etapas/10_credito_productor.parquet` | Preguntas de crédito de la ENA (solicitud, obtención, prestamista y uso) para esos productores |
| `data/diccionario_variables.csv` | Diccionario de variables |
| `R/00_…18_*.R` | Scripts del estudio, numerados en orden de ejecución |
| `R/informe/informe_reproducible.qmd` | **Informe reproducible en Quarto** (HTML y PDF): todas las cifras se calculan al renderizarlo |
| `R/informe/informe_credito_R.tex` | Informe del curso en LaTeX (4 páginas) |
| `R/pipeline_datos.qmd` | Documento Quarto: cómo se construyó la muestra y descripción de los datos |
| `R/dashboard/app.R` | Dashboard interactivo en Shiny (10 pestañas) |
| `docs/` | Versión web del dashboard (Shinylive) que publica GitHub Pages |
| `data/departamentos_centroides.csv` | Punto central de cada departamento para el mapa |
| `R/articulo/articulo_ICALTER_2026_final.docx` | Versión final para ICALTER 2026 (5 páginas, inglés); se arma con `construir_final.py` |
| `R/articulo/` | Versión ampliada del artículo en formato IEEE, en inglés y en español, con el script que la arma |
| `R/resultados/` | Tablas (`.csv`) y figuras (`.png`) que produce cada script |

## Cómo reproducir en Positron

Requisitos: R 4.6 o superior, Positron (trae Quarto incluido). Para rearmar el artículo en Word, también Python 3 (solo biblioteca estándar).

1. Clona el repositorio y ábrelo en Positron con **File → Open Folder**.
2. En la terminal de Positron, desde la raíz del repositorio, corre los scripts en orden (unos 15 minutos):

```bash
Rscript R/00_paquetes.R             # instala las librerías (solo la primera vez)
Rscript R/01_cargar_datos.R         # lee la muestra
Rscript R/02_exploracion.R          # tasas, descriptivos y correlaciones
Rscript R/03_seleccion_variables.R  # SHAP en validación cruzada, redundancia y regla de 1 error estándar
Rscript R/04_modelo_xgboost.R       # XGBoost con caret, validación cruzada agrupada
Rscript R/05_evaluacion.R           # métricas en la prueba, curvas y calibración
Rscript R/06_interpretacion_shap.R  # importancia SHAP y efectos en puntos porcentuales
Rscript R/07_logistica_easystats.R  # regresión logística: odds ratios y diagnósticos
Rscript R/08_prescripcion.R         # focalización y escenarios
Rscript R/09_figuras_articulo.R     # figuras del artículo (inglés)
Rscript R/10_figuras_articulo_es.R  # figuras del artículo (español)
Rscript R/11_validacion.R           # intervalos bootstrap, calibración, validación temporal y espacial
Rscript R/12_departamentos.R        # resultados por departamento con intervalos
Rscript R/13_revision.R             # otros modelos, brecha de propensión, ponderación, datos completos
Rscript R/14_prestamistas.R         # prestamistas públicos, municipales y privados
Rscript R/15_exportar_csv.R         # CSV por productor y datos del dashboard
Rscript R/16_dashboard_departamentos.R  # indicadores, escenarios y mapa por departamento
Rscript R/17_publicar_dashboard.R   # exporta el dashboard a docs/ con Shinylive
Rscript R/18_revisores.R            # validación por ronda, equidad regional y asignación con costos
```

3. Renderiza el informe con el botón **Preview** de Positron o con:

```bash
quarto render R/informe/informe_reproducible.qmd
```

4. Abre el dashboard con **Run App** sobre `R/dashboard/app.R` o con `Rscript -e "shiny::runApp('R/dashboard')"`.
5. Opcional: `python3 R/articulo/construir_final.py` rearma la versión final de ICALTER; `construir_articulo.py` y `construir_articulo_es.py`, la versión ampliada.

Los scripts usan la semilla 2026. Los objetos intermedios (`R/datos/*.rds`) y los CSV de `R/exportes/` no se incluyen porque los scripts los vuelven a crear. El script `R/01b_datos_credito.R` solo hace falta si se reconstruyen los datos desde los microdatos originales del INEI; su resultado ya viene en `data/etapas/`.

## Datos

La fuente es la **Encuesta Nacional Agropecuaria (ENA)** del Instituto Nacional de Estadística e Informática del Perú (INEI), cuyos microdatos son públicos: <https://proyectos.inei.gob.pe/microdatos/>. Los archivos incluidos son derivados ya depurados de esos microdatos:

- **Rondas:** 2016, 2017, 2019 y 2022 a 2025. Se excluyeron 2014, 2015 y 2018 (sin superficie en hectáreas), 2020 (no hubo encuesta) y 2021 (sin módulo de crédito).
- **Población:** pequeños y medianos productores con entrevista completa; ocho reglas de consistencia, sin imputación.
- **Variable objetivo:** `ACCESO_CREDITO` = 1 si solicitó (P901) y obtuvo (P902) crédito en los últimos 12 meses. 11.9 % en la muestra; 10.1 % ponderado.
- **Diseño:** `GRUPO_CV` (conglomerado o segmento), factores de expansión `FACTOR_EXP` y `FACTOR_EXP_MUESTRA`, y partición fija por conglomerado (`CONJUNTO`: 39,868 entrenamiento, 9,969 prueba).

La construcción de estos archivos desde los microdatos originales se describe en `R/pipeline_datos.qmd`, pero no está incluida en este repositorio.

## Licencia

El código se distribuye bajo licencia MIT (ver `LICENSE`). Los datos provienen del INEI; al usarlos, cita a la ENA como fuente.
