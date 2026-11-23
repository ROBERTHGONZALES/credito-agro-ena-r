# 14 · ¿Quién presta? Prestamistas públicos, municipales y privados (pregunta P903 de la ENA).
#   Datos: los 196,566 productores depurados, con factores de expansión para las cifras poblacionales.
#   Tipos de prestamista (un productor puede declarar más de uno):
#     Público nacional  = Agrobanco (P903_1) y programas del Estado (P903_10)
#     Caja municipal    = cajas municipales (P903_2): propiedad municipal, gestión comercial regulada por la SBS
#     Privado regulado  = banca privada (P903_4), cajas rurales (P903_3), financieras/EDPYME (P903_5)
#     Cooperativa u ONG = cooperativas (P903_7) y ONG (P903_6)
#     Informal          = establecimientos comerciales (P903_8) y prestamistas/habilitadores (P903_9)
#   1) Tasa de crédito por cada 100 productores, por tipo y año (¿hubo sustitución cuando cayó Agrobanco?).
#   2) Participación de cada tipo por región y departamento.
#   3) Perfil del cliente de cada tipo y probabilidad predicha de acceso (modelo del estudio, fuera de pliegue).
#   4) Logística entre clientes de un solo tipo: público frente a privado y caja municipal frente a privado.
#   5) Perfil "tipo Agrobanco" (ajustado con 2016–2017): acceso antes y después de la caída de 2019.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost); library(sandwich); library(nanoparquet) })
set.seed(SEMILLA)
m <- readRDS(file.path(DATOS, "modelo_xgboost.rds")); vars <- m$vars; bt <- m$ajuste$bestTune; d49 <- cargar()
TIPOS <- c("Público nacional" = "pub", "Caja municipal" = "cmac", "Privado regulado" = "priv", "Cooperativa u ONG" = "coop", "Informal" = "inf")
COL_T <- c("Público nacional" = "#0072B2", "Caja municipal" = "#E69F00", "Privado regulado" = "#D55E00", "Cooperativa u ONG" = "#009E73", "Informal" = "#999999")

lim <- read_parquet(file.path(RAIZ, "data", "etapas", "08_limpio.parquet")) |> as_tibble() |>
  mutate(ANIO = as.integer(ANIO), REGION = factor(REGION, levels = 1:3, labels = c("Costa", "Sierra", "Selva")),
         DEPARTAMENTO = factor(DEPARTAMENTOS[as.character(DEPARTAMENTO)], levels = levels(d49$DEPARTAMENTO)),
         across(where(is.numeric) & !c(FACTOR_EXP), as.numeric))
pa <- read_parquet(file.path(RAIZ, "data", "etapas", "10_credito_productor.parquet"),
                   col_select = c("ANIO", "K_PROD", paste0("P903_", 1:11), paste0("P904_", 1:10))) |> as_tibble() |> mutate(ANIO = as.integer(ANIO))
x <- lim |> left_join(pa, by = c("ANIO", "K_PROD"))
si <- function(...) as.integer(rowSums(sapply(c(...), function(i) x[[paste0("P903_", i)]] == 1), na.rm = TRUE) > 0)
x <- x |> mutate(pub = si(1, 10), cmac = si(2), priv = si(3, 4, 5), coop = si(6, 7), inf = si(8, 9), agrobanco = si(1),
                 n_tipos = pub + cmac + priv + coop + inf,
                 tipo = case_when(ACCESO_CREDITO == 0 ~ "Sin crédito", n_tipos > 1 ~ "Varios tipos", pub == 1 ~ "Público nacional", cmac == 1 ~ "Caja municipal",
                                  priv == 1 ~ "Privado regulado", coop == 1 ~ "Cooperativa u ONG", inf == 1 ~ "Informal", TRUE ~ "Otro"))
stopifnot(all(x$n_tipos[x$ACCESO_CREDITO == 0] == 0))
h <- x |> filter(ACCESO_CREDITO == 1)

# 1) Por cada 100 productores (ponderado) y participación entre quienes tienen crédito --------------------------
por_anio <- x |> group_by(ANIO) |>
  summarise(productores = n(), con_credito = sum(ACCESO_CREDITO), acceso = 100 * weighted.mean(ACCESO_CREDITO, FACTOR_EXP),
            across(all_of(unname(TIPOS)), ~ 100 * weighted.mean(.x, FACTOR_EXP), .names = "por100_{.col}"),
            across(all_of(unname(TIPOS)), ~ 100 * sum(.x * FACTOR_EXP) / sum(ACCESO_CREDITO * FACTOR_EXP), .names = "part_{.col}"),
            agrobanco_por100 = 100 * weighted.mean(agrobanco, FACTOR_EXP))
write_csv(por_anio, file.path(RES, "14_prestamistas_anio.csv"))

# 2) Región y departamento ----------------------------------------------------------------------
part <- function(g) h |> group_by({{ g }}) |>
  summarise(con_credito = n(), across(all_of(unname(TIPOS)), ~ 100 * weighted.mean(.x, FACTOR_EXP), .names = "part_{.col}"), .groups = "drop")
por_region <- part(REGION); por_dep <- part(DEPARTAMENTO) |> filter(con_credito >= 100) |> arrange(desc(part_pub))
write_csv(por_region, file.path(RES, "14_prestamistas_region.csv")); write_csv(por_dep, file.path(RES, "14_prestamistas_departamento.csv"))

# 3) Perfil y probabilidad predicha (modelo del estudio, predicción fuera de pliegue en los datos completos) -------
xgb_fit <- function(dd) xgb.train(list(objective = "binary:logistic", eta = bt$eta, max_depth = bt$max_depth, min_child_weight = bt$min_child_weight,
                                       subsample = bt$subsample, colsample_bytree = bt$colsample_bytree, gamma = bt$gamma, lambda = bt$lambda,
                                       alpha = bt$alpha, nthread = 12), xgb.DMatrix(matriz(dd, vars), label = dd[[OBJ]]), nrounds = bt$nrounds, verbose = 0)
pl <- groupKFold(x$GRUPO_CV, k = 5); x$p <- NA_real_
for (k in seq_along(pl)) { ent <- pl[[k]]; val <- setdiff(seq_len(nrow(x)), ent); x$p[val] <- predict(xgb_fit(x[ent, ]), xgb.DMatrix(matriz(x[val, ], vars))) }
h <- x |> filter(ACCESO_CREDITO == 1)
med_p <- median(x$p)
perfil <- h |> filter(tipo %in% names(TIPOS)) |> group_by(tipo) |>
  summarise(clientes = n(), pct_clientes = 100 * n() / nrow(h),
            prob_predicha = 100 * weighted.mean(p, FACTOR_EXP), bajo_mediana_prob = 100 * weighted.mean(p < med_p, FACTOR_EXP),
            ha_cosechada_mediana = median(SUP_COSECHADA_HA), edad = weighted.mean(EDAD, FACTOR_EXP), educ_secundaria = 100 * weighted.mean(EDUCACION >= 6, FACTOR_EXP),
            asociado = 100 * weighted.mean(ASOCIADO, FACTOR_EXP), fertilizantes = 100 * weighted.mean(USA_FERTILIZANTES, FACTOR_EXP),
            riego = 100 * weighted.mean(PCT_CULTIVOS_RIEGO, FACTOR_EXP), vende_regional = 100 * weighted.mean(VENDE_LIMA_REGIONAL, FACTOR_EXP),
            sierra = 100 * weighted.mean(REGION == "Sierra", FACTOR_EXP), selva = 100 * weighted.mean(REGION == "Selva", FACTOR_EXP),
            uso_insumos_agricolas = 100 * weighted.mean(P904_1 == 1, FACTOR_EXP, na.rm = TRUE), uso_pecuario = 100 * weighted.mean(P904_2 == 1 | P904_8 == 1 | P904_9 == 1, FACTOR_EXP, na.rm = TRUE),
            uso_mano_obra = 100 * weighted.mean(P904_3 == 1, FACTOR_EXP, na.rm = TRUE), uso_no_agro = 100 * weighted.mean(P904_7 == 1, FACTOR_EXP, na.rm = TRUE)) |>
  arrange(prob_predicha)
write_csv(perfil, file.path(RES, "14_prestamistas_perfil.csv"))

# 4) Logística entre clientes de un solo tipo (OR con errores robustos por conglomerado) ------------------------
prep <- function(dd) dd |> mutate(SUP_COSECHADA_HA = log1p(SUP_COSECHADA_HA), SUP_TOTAL_HA = log1p(SUP_TOTAL_HA), EDAD = EDAD / 10, ANIO_F = factor(ANIO))
pred_or <- setdiff(vars, "DEPARTAMENTO")
or_logit <- function(grupo, ref) {
  dd <- h |> filter(tipo %in% c(grupo, ref)) |> mutate(y = as.integer(tipo == grupo)) |> prep()
  mod <- glm(reformulate(c(pred_or, "ANIO_F"), "y"), data = dd, family = binomial)
  b <- coef(mod); se <- sqrt(diag(vcovCL(mod, cluster = dd$GRUPO_CV)))
  tibble(comparacion = paste(grupo, "vs", ref), n = nrow(dd), termino = names(b), or = exp(b), inf = exp(b - 1.96 * se), sup = exp(b + 1.96 * se)) |>
    filter(!str_detect(termino, "Intercept|ANIO_F"))
}
ors <- bind_rows(or_logit("Público nacional", "Privado regulado"), or_logit("Caja municipal", "Privado regulado"))
write_csv(ors, file.path(RES, "14_prestamistas_odds_ratios.csv"))

# 5) Caída de Agrobanco: productores con perfil "tipo Agrobanco" ------------------------------------------------
base <- h |> filter(ANIO <= 2017) |> mutate(y = agrobanco) |> prep()
mod_ab <- glm(reformulate(pred_or, "y"), data = base, family = binomial)
x$perfil_ab <- predict(mod_ab, prep(x), type = "response")
x <- x |> group_by(ANIO) |> mutate(cuartil_ab = ntile(perfil_ab, 4)) |> ungroup()
crisis <- x |> mutate(grupo = if_else(cuartil_ab == 4, "Perfil tipo Agrobanco (cuartil superior)", "Resto")) |> group_by(grupo, ANIO) |>
  summarise(otros = 100 * weighted.mean(ACCESO_CREDITO == 1 & agrobanco == 0, FACTOR_EXP), acceso = 100 * weighted.mean(ACCESO_CREDITO, FACTOR_EXP),
            pct_agrobanco = 100 * weighted.mean(agrobanco, FACTOR_EXP), n = n(), .groups = "drop")
write_csv(crisis, file.path(RES, "14_prestamistas_crisis_agrobanco.csv"))

# Figura -----------------------------------------------------------------------------------------------
lar <- por_anio |> select(ANIO, starts_with("por100_")) |> pivot_longer(-ANIO, names_to = "t", values_to = "v") |>
  mutate(tipo = factor(names(TIPOS)[match(sub("por100_", "", t), TIPOS)], names(TIPOS)))
g1 <- ggplot(lar, aes(factor(ANIO), v, colour = tipo, group = tipo)) + geom_line(linewidth = 1) + geom_point(size = 2.2) +
  scale_colour_manual(values = COL_T, name = NULL) + labs(x = NULL, y = "Productores con crédito de ese tipo\npor cada 100 productores", title = "Crédito por tipo de prestamista") + tema()
g2 <- crisis |> ggplot(aes(factor(ANIO), acceso, colour = grupo, group = grupo)) + geom_line(linewidth = 1) + geom_point(size = 2.2) +
  geom_line(aes(y = pct_agrobanco), linetype = 2) + scale_colour_manual(values = c("#0072B2", GRIS), name = NULL) +
  labs(x = NULL, y = "Productores con crédito (%)", title = "Acceso total (línea) y de Agrobanco (discontinua)") + tema()
guardar(patchwork::wrap_plots(g1, g2, ncol = 2) & theme(legend.position = "bottom", legend.direction = "vertical"), "14_prestamistas.png", 13, 5.5)

options(width = 220)
cat("\n== Por año (por cada 100 productores, ponderado) ==\n"); print(por_anio |> mutate(across(where(is.double), ~ round(.x, 1))))
cat("\n== Por región (participación entre clientes, ponderada) ==\n"); print(por_region |> mutate(across(where(is.double), ~ round(.x, 1))))
cat("\n== Departamentos ==\n"); print(por_dep |> mutate(across(where(is.double), ~ round(.x, 1))), n = 30)
cat("\n== Perfil ==\n"); print(perfil |> mutate(across(where(is.double), ~ round(.x, 1))))
cat("\n== Odds ratios ==\n"); print(ors |> mutate(across(where(is.double), ~ round(.x, 2))), n = 40)
cat("\n== Crisis Agrobanco ==\n"); print(crisis |> mutate(across(where(is.double), ~ round(.x, 1))), n = 20)
cat("\nVarios tipos:", round(100 * mean(h$tipo == "Varios tipos"), 1), "% de los clientes; mediana p =", round(med_p, 3), "\n")
