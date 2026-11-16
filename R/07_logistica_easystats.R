# 07 · Regresión logística de comparación con easystats: odds ratios, supuestos y desempeño frente a XGBoost.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(easystats) })
d <- cargar(); vars <- readRDS(file.path(DATOS, "variables.rds"))
prep <- function(x) x |> mutate(across(any_of(c("SUP_COSECHADA_HA", "SUP_TOTAL_HA")), ~ log1p(.x)), across(any_of("EDAD"), ~ .x / 10))
tr <- d |> filter(CONJUNTO == "entrenamiento") |> prep(); te <- d |> filter(CONJUNTO == "prueba") |> prep()

modelo <- glm(reformulate(vars, OBJ), data = tr, family = binomial)
par <- model_parameters(modelo, exponentiate = TRUE, ci_method = "wald")           # odds ratios con IC 95 %
or <- as_tibble(par) |> transmute(termino = Parameter, odds_ratio = Coefficient, ic_inf = CI_low, ic_sup = CI_high, z, p)
write_csv(or, file.path(RES, "07_odds_ratios.csv"))
rend <- model_performance(modelo); write_csv(as_tibble(rend), file.path(RES, "07_desempeno_ajuste.csv"))
vif <- check_collinearity(modelo); write_csv(as_tibble(vif), file.path(RES, "07_colinealidad_vif.csv"))
r2 <- r2_tjur(modelo)
hl <- performance_hosmer(modelo, n_bins = 10)
atip <- check_outliers(modelo, method = "cook")

# Desempeño en la prueba con el mismo procedimiento que XGBoost (umbral: máximo F1 en entrenamiento)
p_tr <- predict(modelo, tr, type = "response"); p_te <- predict(modelo, te, type = "response")
u <- umbral_f1(tr[[OBJ]], p_tr)
log_met <- metricas(te[[OBJ]], p_te, u)
xgb <- read_csv(file.path(RES, "05_metricas_prueba.csv"), show_col_types = FALSE)
comp <- xgb |> select(metrica, xgboost) |> mutate(logistica = round(log_met[metrica], 4), diferencia = round(xgboost - logistica, 4))
write_csv(comp, file.path(RES, "07_comparacion_xgboost_logistica.csv"))

etq <- function(t) { for (v in names(ETIQUETAS)) t <- if_else(t == v, ETIQUETAS[[v]], t); t |> str_replace("^REGION", "Región: ") |> str_replace("^DEPARTAMENTO", "Dpto.: ") }
or_plot <- or |> filter(termino != "(Intercept)", !str_detect(termino, "^DEPARTAMENTO")) |>
  mutate(etiqueta = etq(termino) |> str_replace("Edad", "Edad (por 10 años)") |> str_replace("(Superficie .*) \\(ha\\)", "\\1 (log)"))
g <- ggplot(or_plot, aes(odds_ratio, reorder(etiqueta, odds_ratio), colour = odds_ratio > 1)) + geom_vline(xintercept = 1, linetype = "dashed", colour = GRIS) +
  geom_errorbarh(aes(xmin = ic_inf, xmax = ic_sup), height = 0.25) + geom_point(size = 2.6) +
  scale_colour_manual(values = c("TRUE" = AZUL, "FALSE" = NARANJA), guide = "none") + scale_x_log10() +
  labs(x = "Odds ratio (IC 95 %, escala logarítmica)", y = NULL, title = "Regresión logística: odds ratios") + tema()
guardar(g, "07_odds_ratios.png", 8, 5.2)
png(file.path(RES, "07_supuestos.png"), width = 1500, height = 1500, res = 130); print(plot(check_model(modelo, check = c("binned_residuals", "vif", "outliers", "pp_check"), residual_type = "normal"))); dev.off()

sink(file.path(RES, "07_resumen_logistica.txt"))
cat("== Odds ratios (easystats::model_parameters) ==\n"); print(par)
cat("\n== Desempeño del ajuste (model_performance) ==\n"); print(rend)
cat("\n== R2 de Tjur ==\n"); print(r2)
cat("\n== Hosmer–Lemeshow ==\n"); print(hl)
cat("\n== Colinealidad (check_collinearity) ==\n"); print(vif)
cat("\n== Valores atípicos (distancia de Cook) ==\n"); print(atip)
cat("\n== Comparación en la prueba ==\n"); print(comp, n = 20); cat("Umbral logística:", u, "\n")
sink()
cat(readLines(file.path(RES, "07_resumen_logistica.txt")), sep = "\n")
