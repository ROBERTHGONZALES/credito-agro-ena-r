# Acceso a crédito agrario en el Perú: análisis prescriptivo con XGBoost y SHAP en R

Material de reproducción del estudio **"Prescriptive Analysis of Agricultural Credit Access in Peru Using Gradient Boosting and Explainable Machine Learning"**.

Autor: Roberth Carlos Gonzales Mauricio, Facultad de Ingeniería Estadística e Informática, Universidad Nacional del Altiplano (Puno, Perú).

El estudio responde dos preguntas con la Encuesta Nacional Agropecuaria (ENA) 2016–2025:

1. ¿Qué productores pequeños y medianos tienen más probabilidad de obtener crédito?
2. ¿Qué acciones subirían más esa probabilidad?

## Resultados principales

Conjunto de prueba: 9 969 productores que el modelo no vio durante el entrenamiento.

| Métrica | XGBoost | Regresión logística |
|---|---|---|
| AUC-ROC | 0.798 | 0.791 |
| AUC-PR (azar = 0.119) | 0.367 | 0.359 |
| MCC | 0.307 | 0.308 |

- El 20 % de productores con mayor probabilidad concentra el 54 % de quienes tienen crédito.
- El 16.4 % no tiene crédito aunque su perfil es igual al de quienes sí lo tienen (demanda potencial).
- La asociatividad es la acción con mayor efecto: sube la tasa estimada de 12.3 % a 18.7 %. Las cuatro acciones juntas (asociación, mercado, riego y fertilizantes) la llevan a 25.1 %.

Las simulaciones describen asociación, no causalidad probada.

## Contenido

| Ruta | Qué contiene |
|---|---|
| `data/etapas/09_muestra_modelo.parquet` | Muestra de modelado: 49 837 productores, 44 columnas |
| `data/diccionario_variables.csv` | Diccionario: descripción, tipo y pregunta de la ENA de cada columna |
| `R/pipeline_datos.qmd` / `.html` | Documento Quarto: cómo se construyó la muestra y descripción del conjunto de datos |
| `R/00_…09_*.R` | Scripts del estudio, numerados en orden de ejecución |
| `R/_comun.R` | Constantes y funciones compartidas (métricas, matriz de diseño, tema de gráficos) |
| `R/resultados/` | Tablas (`.csv`) y figuras (`.png`) que produce cada script |
| `R/informe/` | Informe en español (LaTeX y PDF, 4 páginas) |
| `R/articulo/` | Artículo en inglés en formato IEEE (`.docx`), sus figuras y el script que lo arma |

## Cómo reproducir

Requisitos: R 4.6 o superior. Para rearmar el artículo, también Python 3 (solo biblioteca estándar).

Desde la carpeta raíz del repositorio:

```bash
Rscript R/00_paquetes.R             # instala las librerías (solo la primera vez)
Rscript R/01_cargar_datos.R         # lee el Parquet y prepara la muestra
Rscript R/02_exploracion.R          # tasas, descriptivos y correlaciones
Rscript R/03_seleccion_variables.R  # SHAP en validación cruzada, redundancia y regla de 1 error estándar
Rscript R/04_modelo_xgboost.R       # XGBoost con caret: 40 combinaciones, validación cruzada agrupada
Rscript R/05_evaluacion.R           # métricas en la prueba, curvas y calibración
Rscript R/06_interpretacion_shap.R  # importancia SHAP y efectos en puntos porcentuales
Rscript R/07_logistica_easystats.R  # regresión logística: odds ratios y diagnósticos
Rscript R/08_prescripcion.R         # focalización, demanda potencial y escenarios
Rscript R/09_figuras_articulo.R     # figuras del artículo
python3 R/articulo/construir_articulo.py   # arma el artículo en Word
quarto render R/pipeline_datos.qmd        # documento del pipeline de datos (HTML)
```

El proceso completo tarda unos 5 minutos en un equipo de escritorio. Los scripts usan la semilla 2026. Los objetos intermedios (`R/datos/*.rds`) no se incluyen porque el script 01 y los siguientes los vuelven a crear.

Versiones usadas: R 4.6.1, xgboost 3.2.1.1, caret 7.0.1, shapviz 0.10.4, además de tidyverse, nanoparquet, easystats, pROC, PRROC y patchwork.

## Datos

La fuente es la **Encuesta Nacional Agropecuaria (ENA)** del Instituto Nacional de Estadística e Informática del Perú (INEI), cuyos microdatos son públicos: <https://proyectos.inei.gob.pe/microdatos/>.

El archivo incluido es una muestra ya limpia, derivada de esos microdatos:

- **Rondas:** 2016, 2017, 2019 y 2022 a 2025. Se excluyeron 2014, 2015 y 2018 (les faltan variables), 2020 (no hubo encuesta) y 2021 (sin módulo de crédito).
- **Población:** productores agropecuarios pequeños y medianos.
- **Variable objetivo:** `ACCESO_CREDITO` (1 = obtuvo crédito, 0 = no). El 11.9 % de la muestra tiene crédito.
- **Predictores candidatos:** 35 (características del productor, tierra, riego, insumos, venta, organización y ubicación). Sus nombres legibles están en `R/_comun.R`.
- **Columnas de diseño:** `ANIO`, `K_PROD` (clave anónima del productor), `GRUPO_CV` (conglomerado), `ESTRATO`, `FACTOR_EXP` y `FACTOR_EXP_MUESTRA` (pesos), `DISENO` y `CONJUNTO` (entrenamiento o prueba).
- **Partición:** 39 868 productores para entrenamiento y 9 969 para prueba, separados por conglomerado para que ningún conglomerado aparezca en ambos lados.

Alcance de la reproducción: este repositorio reproduce el estudio desde la muestra limpia en adelante. La construcción de esa muestra a partir de los microdatos originales no está incluida.

## Método en breve

1. **Selección de variables:** importancia SHAP en validación cruzada, eliminación de pares con correlación de Spearman de 0.70 o más y regla de un error estándar. Quedan 14 de 35 variables.
2. **Modelo:** XGBoost ajustado por búsqueda aleatoria de 9 hiperparámetros, con validación cruzada de 5 grupos por conglomerado y AUC-PR como criterio. No se remuestrean las clases.
3. **Evaluación:** el conjunto de prueba se usa una sola vez. Umbral de clasificación: 0.175 (máximo F1).
4. **Interpretación:** SHAP y, como contraste, regresión logística con easystats.
5. **Prescripción:** curva de ganancia, demanda potencial por departamento y simulación de escenarios por región.

## Licencia

El código se distribuye bajo licencia MIT (ver `LICENSE`). Los datos provienen del INEI; al usarlos, cita a la ENA como fuente.
