# 11 · Validaciones adicionales y optimización con presupuesto.
#   1) Intervalos de confianza bootstrap por conglomerado de las métricas de prueba (XGBoost y logística).
#   2) Calibración: intercepto y pendiente de calibración.
#   3) Validación temporal: entrena con 2016–2023 y evalúa en 2024–2025 (conglomerados no vistos).
#   4) Validación espacial: deja fuera una región natural, entrena con las otras dos y evalúa en ella.
#   5) Incertidumbre de los escenarios: IC bootstrap de las tasas simuladas.
#   6) Optimización: con un presupuesto de K intervenciones (una por productor), elegir a quién y con qué acción
#      para maximizar los nuevos accesos al crédito esperados; se compara con dos reglas sencillas.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost) })
set.seed(SEMILLA)
B <- as.integer(Sys.getenv("N_BOOT", "1000"))
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
vars <- m$vars; u <- m$umbral; booster <- m$ajuste$finalModel$booster; bt <- m$ajuste$bestTune
prob <- function(b, dd) predict(b, xgb.DMatrix(matriz(dd, vars)))
entrenar <- function(dd) xgb.train(list(objective = "binary:logistic", eta = bt$eta, max_depth = bt$max_depth, min_child_weight = bt$min_child_weight,
                                         subsample = bt$subsample, colsample_bytree = bt$colsample_bytree, gamma = bt$gamma, lambda = bt$lambda,
                                         alpha = bt$alpha, nthread = 12),
                                    xgb.DMatrix(matriz(dd, vars), label = dd[[OBJ]]), nrounds = bt$nrounds, verbose = 0)
tr <- d |> filter(CONJUNTO == "entrenamiento"); te <- d |> filter(CONJUNTO == "prueba")
y <- te[[OBJ]]; te$p <- prob(booster, te)

# Logística (mismo modelo que 07)
prep <- function(x) x |> mutate(across(any_of(c("SUP_COSECHADA_HA", "SUP_TOTAL_HA")), ~ log1p(.x)), across(any_of("EDAD"), ~ .x / 10))
glm_m <- glm(reformulate(vars, OBJ), data = prep(tr), family = binomial)
u_log <- umbral_f1(tr[[OBJ]], predict(glm_m, prep(tr), type = "response"))
te$p_log <- predict(glm_m, prep(te), type = "response")

# 1) Bootstrap por conglomerado ----------------------------------------------------------
clus <- split(seq_len(nrow(te)), te$GRUPO_CV)
met4 <- function(yy, pp, uu) metricas(yy, pp, uu)[c("AUC-ROC", "AUC-PR", "MCC", "Brier")]
boot <- map_dfr(seq_len(B), function(b) {
  i <- unlist(clus[sample(length(clus), replace = TRUE)], use.names = FALSE)
  mx <- met4(y[i], te$p[i], u); ml <- met4(y[i], te$p_log[i], u_log)
  tibble(b = b, metrica = names(mx), xgboost = mx, logistica = ml, diferencia = mx - ml)
})
ic <- boot |> group_by(metrica) |>
  summarise(across(c(xgboost, logistica, diferencia), list(inf = ~ quantile(.x, 0.025), sup = ~ quantile(.x, 0.975)))) |>
  left_join(tibble(metrica = c("AUC-ROC", "AUC-PR", "MCC", "Brier"), xgboost = met4(y, te$p, u), logistica = met4(y, te$p_log, u_log)), by = "metrica") |>
  mutate(diferencia = xgboost - logistica)
write_csv(ic, file.path(RES, "11_ic_bootstrap.csv"))

# 2) Calibración -----------------------------------------------------------------------------
lg <- qlogis(pmin(pmax(te$p, 1e-6), 1 - 1e-6))
cal_pend <- coef(glm(y ~ lg, family = binomial))[2]
cal_int <- coef(glm(y ~ offset(lg), family = binomial))[1]
dec <- tibble(y = y, p = te$p) |> mutate(decil = ntile(p, 10)) |> group_by(decil) |> summarise(pred = mean(p), obs = mean(y), n = n())
ece <- sum(dec$n * abs(dec$pred - dec$obs)) / sum(dec$n)
calib <- tibble(intercepto = cal_int, pendiente = cal_pend, ece = ece, decil_sup_pred = 100 * dec$pred[10], decil_sup_obs = 100 * dec$obs[10])
write_csv(calib, file.path(RES, "11_calibracion.csv"))

# 3) Validación temporal y 4) espacial ---------------------------------------------------------
evaluar <- function(dtr, dte, nombre) {
  dte <- dte |> filter(!GRUPO_CV %in% dtr$GRUPO_CV)          # solo conglomerados no vistos
  b <- entrenar(dtr); pp <- prob(b, dte)
  tibble(validacion = nombre, n_entrenamiento = nrow(dtr), n_evaluacion = nrow(dte), prevalencia = 100 * mean(dte[[OBJ]]),
         auc_roc = auc_roc(dte[[OBJ]], pp), auc_pr = auc_pr(dte[[OBJ]], pp), azar_pr = mean(dte[[OBJ]]),
         mcc = metricas(dte[[OBJ]], pp, u)[["MCC"]], prob_media = 100 * mean(pp))
}
fuera <- bind_rows(
  evaluar(filter(d, ANIO <= 2023), filter(d, ANIO >= 2024), "Temporal: 2016-2023 -> 2024-2025"),
  map_dfr(levels(d$REGION), ~ evaluar(filter(d, REGION != .x), filter(d, REGION == .x), paste("Espacial: sin", .x))))
fuera <- fuera |> mutate(lift_pr = auc_pr / azar_pr)
write_csv(fuera, file.path(RES, "11_validacion_temporal_espacial.csv"))

# 5) Incertidumbre de los escenarios -----------------------------------------------------------
acciones <- list(ASOCIADO = 1, VENDE_LIMA_REGIONAL = 1, PCT_CULTIVOS_RIEGO = 1, USA_FERTILIZANTES = 1)
escen <- list("Asociatividad" = "ASOCIADO", "Venta a mercados regionales/Lima" = "VENDE_LIMA_REGIONAL",
              "Riego en todos los cultivos" = "PCT_CULTIVOS_RIEGO", "Uso de fertilizantes" = "USA_FERTILIZANTES",
              "Asociatividad + mercado" = c("ASOCIADO", "VENDE_LIMA_REGIONAL"), "Las cuatro palancas" = names(acciones))
p_esc <- map(escen, function(vs) { dd <- te; for (v in vs) dd[[v]] <- acciones[[v]]; prob(booster, dd) })
ambitos <- c("Nacional", levels(te$REGION))
filas <- map(ambitos, ~ if (.x == "Nacional") rep(TRUE, nrow(te)) else te$REGION == .x)
names(filas) <- ambitos
boot_esc <- map_dfr(seq_len(B), function(b) {
  i <- unlist(clus[sample(length(clus), replace = TRUE)], use.names = FALSE)
  imap_dfr(p_esc, function(p2, nombre) map_dfr(ambitos, function(a) {
    j <- i[filas[[a]][i]]
    tibble(escenario = nombre, ambito = a, simulada = 100 * mean(p2[j]), ganancia = 100 * mean(p2[j] - te$p[j]))
  }))
})
ic_esc <- boot_esc |> group_by(escenario, ambito) |>
  summarise(sim_inf = quantile(simulada, 0.025), sim_sup = quantile(simulada, 0.975),
            gan_inf = quantile(ganancia, 0.025), gan_sup = quantile(ganancia, 0.975), .groups = "drop") |>
  left_join(imap_dfr(p_esc, function(p2, nombre) map_dfr(ambitos, function(a)
    tibble(escenario = nombre, ambito = a, base = 100 * mean(te$p[filas[[a]]]), simulada = 100 * mean(p2[filas[[a]]]),
           ganancia = simulada - base))), by = c("escenario", "ambito"))
write_csv(ic_esc, file.path(RES, "11_escenarios_ic.csv"))

# 6) Optimización con presupuesto ---------------------------------------------------------
# Ganancia individual de cada acción (solo para quien no la tiene); a cada productor se le asigna su mejor acción.
# Con costo igual por intervención y como máximo una por productor, tomar los K mayores es la solución óptima.
gan_tab <- map_dfc(names(acciones), function(v) {
  dd <- te; dd[[v]] <- acciones[[v]]; g <- prob(booster, dd) - te$p
  tibble(!!v := ifelse(te[[v]] < acciones[[v]], g, NA_real_))
})
mejor_acc <- names(acciones)[apply(as.matrix(gan_tab), 1, function(r) if (all(is.na(r))) NA_integer_ else which.max(r))]
mejor_gan <- apply(as.matrix(gan_tab), 1, function(r) if (all(is.na(r))) 0 else max(r, na.rm = TRUE))
sin_credito <- y == 0
cand <- tibble(i = seq_len(nrow(te)), region = as.character(te$REGION), p = te$p, accion = mejor_acc, gan = mejor_gan,
               gan_asoc = coalesce(gan_tab$ASOCIADO, 0)) |> filter(sin_credito[i], !is.na(accion))
presupuestos <- c(500, 1000, 2000)
reglas <- map_dfr(presupuestos, function(K) {
  opt <- cand |> slice_max(gan, n = K, with_ties = FALSE)
  asoc_opt <- cand |> slice_max(gan_asoc, n = K, with_ties = FALSE)
  alta_p <- cand |> slice_max(p, n = K, with_ties = FALSE)
  azar <- mean(replicate(200, sum(cand$gan_asoc[sample(nrow(cand), K)])))
  tibble(K = K,
         optima_mejor_accion = sum(opt$gan), optima_solo_asociatividad = sum(asoc_opt$gan_asoc),
         mayor_probabilidad_asociatividad = sum(alta_p$gan_asoc), azar_asociatividad = azar,
         opt_asoc = mean(opt$accion == "ASOCIADO") * 100, opt_mercado = mean(opt$accion == "VENDE_LIMA_REGIONAL") * 100,
         opt_riego = mean(opt$accion == "PCT_CULTIVOS_RIEGO") * 100, opt_fert = mean(opt$accion == "USA_FERTILIZANTES") * 100,
         opt_costa = mean(opt$region == "Costa") * 100, opt_sierra = mean(opt$region == "Sierra") * 100, opt_selva = mean(opt$region == "Selva") * 100,
         opt_p_media = 100 * mean(opt$p), opt_gan_media = 100 * mean(opt$gan))
})
write_csv(reglas, file.path(RES, "11_optimizacion.csv"))
asig <- cand |> slice_max(gan, n = 1000, with_ties = FALSE) |> count(region, accion) |> group_by(region) |> mutate(pct = 100 * n / sum(n))
write_csv(asig, file.path(RES, "11_optimizacion_asignacion.csv"))

print(ic, width = 200); print(calib); print(fuera, width = 200)
print(ic_esc |> filter(ambito == "Nacional"), width = 200); print(reglas, width = 250); print(asig, n = 20)
