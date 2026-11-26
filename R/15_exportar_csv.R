# 15 · Exporta en CSV los datos de prestamistas y los insumos del dashboard.
#   R/exportes/
#     productores_prestamistas.csv   196,566 productores depurados: ubicación, características, solicitud, obtención y prestamista
#     LEEME.txt                      diccionario de columnas
#     14_prestamistas_*.csv          resultados agregados del script 14
#   R/dashboard/datos/               tablas pequeñas que lee el dashboard (agregados y predicciones de prueba)
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(xgboost); library(nanoparquet) })
EXP <- file.path(BASE, "exportes"); DSH <- file.path(BASE, "dashboard", "datos")
dir.create(EXP, showWarnings = FALSE); dir.create(DSH, recursive = TRUE, showWarnings = FALSE)
d49 <- cargar()

# 1) Productores con su prestamista ----------------------------------------------------------------
fuentes <- c("agrobanco", "caja_municipal", "caja_rural", "banca_privada", "financiera_edpyme", "ong", "cooperativa",
             "establecimiento_comercial", "prestamista_habilitador", "programa_estado", "otro")
lim <- read_parquet(file.path(RAIZ, "data", "etapas", "08_limpio.parquet")) |> as_tibble() |>
  mutate(ANIO = as.integer(ANIO), REGION = factor(REGION, levels = 1:3, labels = c("Costa", "Sierra", "Selva")),
         DEPARTAMENTO = DEPARTAMENTOS[as.character(DEPARTAMENTO)])
pa <- read_parquet(file.path(RAIZ, "data", "etapas", "10_credito_productor.parquet"),
                   col_select = c("ANIO", "K_PROD", "UBIGEO", "P901", "P902", paste0("P903_", 1:11))) |> as_tibble() |> mutate(ANIO = as.integer(ANIO))
x <- lim |> left_join(pa, by = c("ANIO", "K_PROD"))
for (i in 1:11) x[[paste0("presto_", fuentes[i])]] <- as.integer(coalesce(x[[paste0("P903_", i)]] == 1, FALSE))
x <- x |> mutate(
  solicito_credito = as.integer(P901 == 1), obtuvo_credito = ACCESO_CREDITO,
  tipo_publico = as.integer(presto_agrobanco | presto_programa_estado), tipo_caja_municipal = presto_caja_municipal,
  tipo_privado_regulado = as.integer(presto_banca_privada | presto_caja_rural | presto_financiera_edpyme),
  tipo_cooperativa_ong = as.integer(presto_cooperativa | presto_ong), tipo_informal = as.integer(presto_establecimiento_comercial | presto_prestamista_habilitador),
  n_tipos = tipo_publico + tipo_caja_municipal + tipo_privado_regulado + tipo_cooperativa_ong + tipo_informal,
  tipo_prestamista = case_when(obtuvo_credito == 0 ~ "Sin crédito", n_tipos > 1 ~ "Varios tipos", tipo_publico == 1 ~ "Público nacional",
                               tipo_caja_municipal == 1 ~ "Caja municipal", tipo_privado_regulado == 1 ~ "Privado regulado",
                               tipo_cooperativa_ong == 1 ~ "Cooperativa u ONG", tipo_informal == 1 ~ "Informal", TRUE ~ "Otro"))
en_muestra <- d49 |> select(ANIO, K_PROD, CONJUNTO)
x <- x |> left_join(en_muestra, by = c("ANIO", "K_PROD")) |> mutate(conjunto_muestra = coalesce(as.character(CONJUNTO), "fuera de la muestra"))
salida <- x |> select(ANIO, K_PROD, GRUPO_CV, UBIGEO, DEPARTAMENTO, REGION, DISENO, FACTOR_EXP, conjunto_muestra,
                      solicito_credito, obtuvo_credito, tipo_prestamista, starts_with("tipo_") & !tipo_prestamista, starts_with("presto_"),
                      EDAD, SEXO_MUJER, EDUCACION, TAM_HOGAR, SUP_TOTAL_HA, SUP_COSECHADA_HA, PCT_CULTIVOS_RIEGO, USA_FERTILIZANTES,
                      USA_PLAGUICIDAS, PCT_CULTIVOS_VENDIDOS, VENDE_LIMA_REGIONAL, ASOCIADO, ARRIENDA_TIERRA, CAPACITACION, ASISTENCIA_TECNICA)
stopifnot(nrow(salida) == 196566)
write_csv(salida, file.path(EXP, "productores_prestamistas.csv"), na = "")
file.copy(list.files(RES, "^14_prestamistas_.*\\.csv$", full.names = TRUE), EXP, overwrite = TRUE)
writeLines(c(
  "Datos de prestamistas · ENA 2016–2025 (rondas 2016, 2017, 2019, 2022–2025), pequeños y medianos productores depurados",
  "Fuente: INEI, Encuesta Nacional Agropecuaria (microdatos públicos). Elaboración propia.",
  "",
  "productores_prestamistas.csv — una fila por productor y año (196,566 filas)",
  "  ANIO, K_PROD: año y llave del productor dentro del año",
  "  GRUPO_CV: conglomerado o segmento de muestreo · UBIGEO: código del distrito · DEPARTAMENTO, REGION: ubicación",
  "  DISENO: diseño muestral (conglomerados hasta 2022, marco de áreas desde 2023)",
  "  FACTOR_EXP: factor de expansión (úsalo para cifras de población)",
  "  conjunto_muestra: entrenamiento / prueba si el productor está en la muestra de modelado de 49,837; si no, 'fuera de la muestra'",
  "  solicito_credito (P901): 1 si solicitó crédito en los últimos 12 meses · obtuvo_credito (P901 y P902): 1 si lo solicitó y lo obtuvo",
  "  tipo_prestamista: tipo único del productor (Sin crédito, Público nacional, Caja municipal, Privado regulado, Cooperativa u ONG, Informal, Varios tipos)",
  "  tipo_*: 1 si se prestó de ese tipo (un productor puede tener más de uno)",
  "     público = Agrobanco + programas del Estado; caja_municipal = cajas municipales; privado_regulado = banca privada + cajas rurales + financieras/EDPYME",
  "     cooperativa_ong = cooperativas + ONG; informal = establecimientos comerciales + prestamistas/habilitadores",
  "  presto_*: 1 si se prestó de esa entidad (pregunta P903, 11 opciones)",
  "  Resto de columnas: características del productor (ver data/diccionario_variables.csv del repositorio)",
  "",
  "14_prestamistas_*.csv — resultados agregados del script R/14_prestamistas.R (ponderados con FACTOR_EXP)",
  "  pub = público nacional, cmac = caja municipal, priv = privado regulado, coop = cooperativa u ONG, inf = informal",
  "  por100_*: prestatarios de ese tipo por cada 100 productores · part_*: % de los prestatarios que usó ese tipo"),
  file.path(EXP, "LEEME.txt"))

# 2) Insumos del dashboard ---------------------------------------------------------------------------
m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
te <- d49 |> filter(CONJUNTO == "prueba")
te$p <- predict(m$ajuste$finalModel$booster, xgb.DMatrix(matriz(te, m$vars)))
te <- te |> left_join(pa |> select(ANIO, K_PROD, P901), by = c("ANIO", "K_PROD"))
write_csv(te |> transmute(ANIO, DEPARTAMENTO = as.character(DEPARTAMENTO), REGION = as.character(REGION), y = ACCESO_CREDITO,
                          p = round(p, 5), solicito = as.integer(P901 == 1), asociado = ASOCIADO, ha_cosechada = SUP_COSECHADA_HA, peso = FACTOR_EXP_MUESTRA),
          file.path(DSH, "prueba_predicciones.csv"))
region_principal <- x |> count(DEPARTAMENTO, REGION) |> group_by(DEPARTAMENTO) |> slice_max(n, n = 1, with_ties = FALSE) |> select(DEPARTAMENTO, REGION)
dep_anio <- x |> group_by(DEPARTAMENTO, ANIO) |>
  summarise(productores = n(), acceso = 100 * weighted.mean(obtuvo_credito, FACTOR_EXP), solicitud = 100 * weighted.mean(solicito_credito, FACTOR_EXP, na.rm = TRUE),
            across(c(tipo_publico, tipo_caja_municipal, tipo_privado_regulado, tipo_cooperativa_ong, tipo_informal), ~ 100 * weighted.mean(.x, FACTOR_EXP)), .groups = "drop") |>
  left_join(region_principal, by = "DEPARTAMENTO")
write_csv(dep_anio, file.path(DSH, "departamento_anio.csv"))
reg_anio <- x |> group_by(REGION, ANIO) |>
  summarise(acceso = 100 * weighted.mean(obtuvo_credito, FACTOR_EXP), solicitud = 100 * weighted.mean(solicito_credito, FACTOR_EXP, na.rm = TRUE), .groups = "drop")
nac_anio <- x |> group_by(ANIO) |>
  summarise(REGION = "Nacional", acceso = 100 * weighted.mean(obtuvo_credito, FACTOR_EXP), solicitud = 100 * weighted.mean(solicito_credito, FACTOR_EXP, na.rm = TRUE))
write_csv(bind_rows(nac_anio, reg_anio), file.path(DSH, "acceso_anio.csv"))
for (f in c("14_prestamistas_anio.csv", "14_prestamistas_perfil.csv", "14_prestamistas_crisis_agrobanco.csv", "13_departamentos_datos_completos.csv",
            "13_benchmarks.csv", "11_escenarios_ic.csv", "13_escenarios_ponderados.csv", "18_asignacion_k.csv", "08_focalizacion.csv",
            "06_importancia_shap.csv", "06_efectos_pp.csv", "13_sensibilidad_umbral.csv", "11_validacion_temporal_espacial.csv"))
  file.copy(file.path(RES, f), DSH, overwrite = TRUE)
cat("ok:", nrow(salida), "productores;", length(list.files(DSH)), "archivos para el dashboard\n")
