# 16 · Datos por departamento para el dashboard (ficha, comparación, mapa y escenarios).
#   Usa los 196,566 productores depurados con sus factores de expansión.
#   Salidas en R/dashboard/datos/:
#     dep_perfil.csv       indicadores ponderados de cada departamento y del Perú (todas las rondas)
#     dep_escenarios.csv   tasa predicha y simulada por escenario y departamento (modelo final; simulación, no efecto causal)
#     dep_shap.csv         efecto propio del departamento en el modelo (SHAP medio, conjunto de prueba)
#     dep_prestamistas.csv participación de cada tipo de prestamista entre los prestatarios del departamento
#   Centroides del mapa: data/departamentos_centroides.csv (mediana de las coordenadas de los segmentos de la ENA;
#   solo un punto por departamento). Se recalcula si existe la base productor-año local; si no, se usa el archivo incluido.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(xgboost); library(nanoparquet) })
DSH <- file.path(BASE, "dashboard", "datos"); dir.create(DSH, recursive = TRUE, showWarnings = FALSE)
d49 <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds")); vars <- m$vars; booster <- m$ajuste$finalModel$booster

lim <- read_parquet(file.path(RAIZ, "data", "etapas", "08_limpio.parquet")) |> as_tibble() |>
  mutate(ANIO = as.integer(ANIO), REGION = factor(REGION, levels = 1:3, labels = c("Costa", "Sierra", "Selva")),
         DEPARTAMENTO = factor(DEPARTAMENTOS[as.character(DEPARTAMENTO)], levels = levels(d49$DEPARTAMENTO)),
         across(where(is.numeric) & !c(FACTOR_EXP), as.numeric))
cred <- read_parquet(file.path(RAIZ, "data", "etapas", "10_credito_productor.parquet"), col_select = c("ANIO", "K_PROD", "P901", "P902")) |>
  as_tibble() |> mutate(ANIO = as.integer(ANIO))
x <- lim |> left_join(cred, by = c("ANIO", "K_PROD")) |> filter(DEPARTAMENTO != "Callao")

# Centroides --------------------------------------------------------------------------------------
f_cent <- file.path(RAIZ, "data", "departamentos_centroides.csv")
f_pa <- file.path(RAIZ, "data", "etapas", "06_productor_anio_2014_2025.parquet")
if (file.exists(f_pa)) {
  geo <- read_parquet(f_pa, col_select = c("ANIO", "K_PROD", "LATITUD", "LONGITUD")) |> as_tibble() |> mutate(ANIO = as.integer(ANIO))
  cent <- x |> select(ANIO, K_PROD, DEPARTAMENTO) |> left_join(geo, by = c("ANIO", "K_PROD")) |>
    filter(between(LATITUD, -19, 0.5), between(LONGITUD, -82, -68)) |>
    group_by(DEPARTAMENTO) |> summarise(lat = median(LATITUD), lon = median(LONGITUD), .groups = "drop")
  write_csv(cent, f_cent)
}
cent <- read_csv(f_cent, show_col_types = FALSE)

# 1) Perfil ponderado ----------------------------------------------------------------------------------
perfil_de <- function(dd) dd |> summarise(
  productores = n(), conglomerados = n_distinct(GRUPO_CV),
  acceso = 100 * weighted.mean(ACCESO_CREDITO, FACTOR_EXP), solicitud = 100 * weighted.mean(P901 == 1, FACTOR_EXP),
  aprobacion = 100 * sum(FACTOR_EXP * (P902 == 1 & P901 == 1)) / sum(FACTOR_EXP * (P901 == 1)),
  ha_cosechada = median(SUP_COSECHADA_HA), ha_total = median(SUP_TOTAL_HA), edad = weighted.mean(EDAD, FACTOR_EXP),
  mujer = 100 * weighted.mean(SEXO_MUJER, FACTOR_EXP), secundaria = 100 * weighted.mean(EDUCACION >= 6, FACTOR_EXP),
  lengua_nativa = 100 * weighted.mean(LENGUA_NATIVA, FACTOR_EXP), tam_hogar = weighted.mean(TAM_HOGAR, FACTOR_EXP),
  asociado = 100 * weighted.mean(ASOCIADO, FACTOR_EXP), fertilizantes = 100 * weighted.mean(USA_FERTILIZANTES, FACTOR_EXP),
  riego = 100 * weighted.mean(PCT_CULTIVOS_RIEGO, FACTOR_EXP), vende_regional = 100 * weighted.mean(VENDE_LIMA_REGIONAL, FACTOR_EXP),
  capacitacion = 100 * weighted.mean(CAPACITACION, FACTOR_EXP), asistencia = 100 * weighted.mean(ASISTENCIA_TECNICA, FACTOR_EXP),
  arrienda = 100 * weighted.mean(ARRIENDA_TIERRA, FACTOR_EXP))
region_principal <- x |> count(DEPARTAMENTO, REGION) |> group_by(DEPARTAMENTO) |> slice_max(n, n = 1, with_ties = FALSE) |> select(DEPARTAMENTO, region = REGION)
perfil <- bind_rows(x |> group_by(DEPARTAMENTO) |> perfil_de() |> left_join(region_principal, by = "DEPARTAMENTO") |>
                      mutate(DEPARTAMENTO = as.character(DEPARTAMENTO), region = as.character(region)),
                    x |> perfil_de() |> mutate(DEPARTAMENTO = "Perú", region = "Nacional")) |>
  left_join(cent |> mutate(DEPARTAMENTO = as.character(DEPARTAMENTO)), by = "DEPARTAMENTO")
write_csv(perfil, file.path(DSH, "dep_perfil.csv"))

# 2) Escenarios por departamento (modelo final aplicado a todos los productores depurados) -------------------
acciones <- list(ASOCIADO = 1, VENDE_LIMA_REGIONAL = 1, PCT_CULTIVOS_RIEGO = 1, USA_FERTILIZANTES = 1)
escen <- list("Asociatividad" = "ASOCIADO", "Venta a mercados" = "VENDE_LIMA_REGIONAL", "Riego en todos los cultivos" = "PCT_CULTIVOS_RIEGO",
              "Uso de fertilizantes" = "USA_FERTILIZANTES", "Asociatividad + mercado" = c("ASOCIADO", "VENDE_LIMA_REGIONAL"),
              "Las cuatro acciones" = names(acciones))
pr <- function(dd) predict(booster, xgb.DMatrix(matriz(dd, vars)))
x$p <- pr(x)
sims <- imap_dfc(escen, function(vs, nombre) { dd <- x; for (v in vs) dd[[v]] <- acciones[[v]]; tibble(!!nombre := pr(dd)) })
falta <- imap_dfc(escen, function(vs, nombre) tibble(!!nombre := Reduce(`|`, lapply(vs, function(v) x[[v]] < acciones[[v]]))))
esc_dep <- function(idx, nombre) imap_dfr(escen, function(vs, e) tibble(
  DEPARTAMENTO = nombre, escenario = e, base = 100 * weighted.mean(x$p[idx], x$FACTOR_EXP[idx]),
  simulada = 100 * weighted.mean(sims[[e]][idx], x$FACTOR_EXP[idx]), sin_condicion = 100 * weighted.mean(falta[[e]][idx], x$FACTOR_EXP[idx])))
esc <- bind_rows(map_dfr(levels(droplevels(x$DEPARTAMENTO)), ~ esc_dep(which(x$DEPARTAMENTO == .x), .x)), esc_dep(seq_len(nrow(x)), "Perú")) |>
  mutate(ganancia = simulada - base)
write_csv(esc, file.path(DSH, "dep_escenarios.csv"))

# 3) y 4) Efecto propio del departamento y prestamistas ------------------------------------------------------
file.copy(file.path(RES, "06_shap_departamento.csv"), file.path(DSH, "dep_shap.csv"), overwrite = TRUE)
file.copy(file.path(RES, "14_prestamistas_departamento.csv"), file.path(DSH, "dep_prestamistas.csv"), overwrite = TRUE)
cat("ok:", nrow(perfil) - 1, "departamentos;", nrow(esc), "filas de escenarios\n")
print(perfil |> select(DEPARTAMENTO, region, productores, acceso, solicitud, asociado, lat, lon) |> mutate(across(where(is.double), ~ round(.x, 1))), n = 30)
