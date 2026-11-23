# 13 · Análisis de la revisión.
#   1) Comparación con otros modelos (logística, logística penalizada, bosque aleatorio, GAM) con IC bootstrap.
#   2) Solicitud y aprobación (P901/P902) y sensibilidad de la "brecha de propensión" al umbral.
#   3) Tasas ponderadas con el factor de expansión (alcance poblacional).
#   4) Logística con errores robustos por conglomerado; odds ratios de región sin departamento.
#   5) Asignación con presupuesto evaluada con modelos independientes (ajuste cruzado) e IC bootstrap.
#   6) Comprobación con los 196,566 productores depurados (validación cruzada agrupada, departamentos).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost); library(glmnet); library(ranger); library(mgcv); library(sandwich); library(nanoparquet) })
set.seed(SEMILLA)
B <- as.integer(Sys.getenv("N_BOOT", "1000"))
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
vars <- m$vars; u <- m$umbral; booster <- m$ajuste$finalModel$booster; bt <- m$ajuste$bestTune
xgb_fit <- function(dd) xgb.train(list(objective = "binary:logistic", eta = bt$eta, max_depth = bt$max_depth, min_child_weight = bt$min_child_weight,
                                       subsample = bt$subsample, colsample_bytree = bt$colsample_bytree, gamma = bt$gamma, lambda = bt$lambda,
                                       alpha = bt$alpha, nthread = 12), xgb.DMatrix(matriz(dd, vars), label = dd[[OBJ]]), nrounds = bt$nrounds, verbose = 0)
xgb_p <- function(b, dd) predict(b, xgb.DMatrix(matriz(dd, vars)))
prep <- function(x) x |> mutate(across(any_of(c("SUP_COSECHADA_HA", "SUP_TOTAL_HA")), ~ log1p(.x)), across(any_of("EDAD"), ~ .x / 10))
pa <- read_parquet(file.path(RAIZ, "data", "etapas", "10_credito_productor.parquet"), col_select = c("ANIO", "K_PROD", "P901", "P902")) |>
  as_tibble() |> mutate(ANIO = as.integer(ANIO))
d <- d |> left_join(pa, by = c("ANIO", "K_PROD")); stopifnot(!anyNA(d$P901))
tr <- d |> filter(CONJUNTO == "entrenamiento"); te <- d |> filter(CONJUNTO == "prueba"); y <- te[[OBJ]]
clus <- split(seq_len(nrow(te)), te$GRUPO_CV)
remuestra <- function() unlist(clus[sample(length(clus), replace = TRUE)], use.names = FALSE)
q <- function(x) unname(quantile(x, c(0.025, 0.975)))

# 1) Comparación de modelos -------------------------------------------------------------------
te$p <- xgb_p(booster, te)
glm_m <- glm(reformulate(vars, OBJ), data = prep(tr), family = binomial)
p_glm <- predict(glm_m, prep(te), type = "response")
Xtr <- matriz(prep(tr), vars); Xte <- matriz(prep(te), vars)
fold_id <- as.integer(factor(tr$GRUPO_CV)) %% 5 + 1
en <- cv.glmnet(Xtr, tr[[OBJ]], family = "binomial", alpha = 0.5, foldid = fold_id, type.measure = "deviance")
p_en <- as.numeric(predict(en, Xte, s = "lambda.min", type = "response"))
rf <- ranger(x = matriz(tr, vars), y = factor(tr[[OBJ]]), probability = TRUE, num.trees = 500, min.node.size = 20, num.threads = 12, seed = SEMILLA)
p_rf <- predict(rf, matriz(te, vars))$predictions[, "1"]
bin <- setdiff(vars, c("SUP_COSECHADA_HA", "SUP_TOTAL_HA", "EDAD", "TAM_HOGAR", "EDUCACION", "PCT_CULTIVOS_RIEGO", "PCT_CULTIVOS_VENDIDOS", "REGION", "DEPARTAMENTO"))
f_gam <- as.formula(paste(OBJ, "~ s(EDAD) + s(SUP_COSECHADA_HA) + s(SUP_TOTAL_HA) + s(TAM_HOGAR, k = 6) + s(EDUCACION, k = 6) + s(PCT_CULTIVOS_RIEGO, k = 5) + s(PCT_CULTIVOS_VENDIDOS, k = 5) +",
                          paste(c(bin, "REGION", "DEPARTAMENTO"), collapse = " + ")))
gam_m <- bam(f_gam, data = prep(tr), family = binomial, discrete = TRUE, nthreads = 8)
p_gam <- as.numeric(predict(gam_m, prep(te), type = "response"))
modelos <- list("XGBoost" = te$p, "Logística" = p_glm, "Logística penalizada (elastic net)" = p_en, "Bosque aleatorio" = p_rf, "GAM" = p_gam)
m3 <- function(pp, i) c(auc_roc = auc_roc(y[i], pp[i]), auc_pr = auc_pr(y[i], pp[i]), brier = mean((pp[i] - y[i])^2))
bs <- replicate(B, { i <- remuestra(); sapply(modelos, m3, i = i) }, simplify = "array")      # 3 × modelos × B
bench <- imap_dfr(modelos, function(pp, nm) {
  pt <- m3(pp, seq_along(y)); k <- which(names(modelos) == nm)
  dif <- bs[, 1, ] - bs[, k, ]
  tibble(modelo = nm, auc_roc = pt[1], auc_roc_inf = q(bs[1, k, ])[1], auc_roc_sup = q(bs[1, k, ])[2],
         auc_pr = pt[2], auc_pr_inf = q(bs[2, k, ])[1], auc_pr_sup = q(bs[2, k, ])[2], brier = pt[3],
         dif_roc_xgb = m3(modelos[[1]], seq_along(y))[1] - pt[1], dif_roc_inf = q(dif[1, ])[1], dif_roc_sup = q(dif[1, ])[2],
         dif_pr_xgb = m3(modelos[[1]], seq_along(y))[2] - pt[2], dif_pr_inf = q(dif[2, ])[1], dif_pr_sup = q(dif[2, ])[2])
})
write_csv(bench, file.path(RES, "13_benchmarks.csv"))

# 2) Solicitud, aprobación y brecha de propensión ---------------------------------------------------
sol <- tibble(conjunto = c("muestra", "prueba"), solicito = c(mean(d$P901 == 1), mean(te$P901 == 1)) * 100,
              aprobado_si_solicito = c(mean(d$P902[d$P901 == 1] == 1), mean(te$P902[te$P901 == 1] == 1)) * 100)
write_csv(sol, file.path(RES, "13_solicitud.csv"))
dep_rank <- function(flag) te |> mutate(f = flag) |> group_by(DEPARTAMENTO) |> summarise(s = mean(f), .groups = "drop")
base_rank <- dep_rank(te$p >= u & y == 0)
sens <- map_dfr(c(0.10, 0.15, u, 0.20, 0.25, 0.30), function(t) {
  flag <- te$p >= t & y == 0; marcados <- te$p >= t
  tibble(umbral = t, brecha_pct_todos = 100 * mean(flag), brecha_pct_sin_credito = 100 * mean(flag[y == 0]),
         precision = 100 * mean(y[marcados] == 1), solicito_en_brecha = 100 * mean(te$P901[flag] == 1),
         spearman_dptos = cor(base_rank$s, dep_rank(flag)$s, method = "spearman"))
})
write_csv(sens, file.path(RES, "13_sensibilidad_umbral.csv"))
dep <- read_csv(file.path(RES, "12_departamentos_prueba.csv"), show_col_types = FALSE)
corr_dep <- cor(dep$tasa_credito, dep$potencial, method = "spearman")

# 3) Tasas ponderadas --------------------------------------------------------------------------------
w <- te$FACTOR_EXP_MUESTRA
acciones <- list(ASOCIADO = 1, VENDE_LIMA_REGIONAL = 1, PCT_CULTIVOS_RIEGO = 1, USA_FERTILIZANTES = 1)
escen <- list("Asociatividad" = "ASOCIADO", "Venta a mercados regionales/Lima" = "VENDE_LIMA_REGIONAL", "Riego en todos los cultivos" = "PCT_CULTIVOS_RIEGO",
              "Uso de fertilizantes" = "USA_FERTILIZANTES", "Asociatividad + mercado" = c("ASOCIADO", "VENDE_LIMA_REGIONAL"), "Las cuatro palancas" = names(acciones))
p_esc <- map(escen, function(vs) { dd <- te; for (v in vs) dd[[v]] <- acciones[[v]]; xgb_p(booster, dd) })
pond <- bind_rows(tibble(escenario = "Base", sin_ponderar = 100 * mean(te$p), ponderado = 100 * weighted.mean(te$p, w)),
                  imap_dfr(p_esc, ~ tibble(escenario = .y, sin_ponderar = 100 * mean(.x), ponderado = 100 * weighted.mean(.x, w)))) |>
  mutate(ganancia_sin_ponderar = sin_ponderar - sin_ponderar[1], ganancia_ponderada = ponderado - ponderado[1])
obs <- tibble(observada_sin_ponderar = 100 * mean(y), observada_ponderada = 100 * weighted.mean(y, w),
              predicha_sin_ponderar = 100 * mean(te$p), predicha_ponderada = 100 * weighted.mean(te$p, w))
write_csv(pond, file.path(RES, "13_escenarios_ponderados.csv")); write_csv(obs, file.path(RES, "13_tasas_ponderadas.csv"))

# 4) Logística: errores robustos por conglomerado ----------------------------------------------------
or_tab <- function(mod, cl) {
  b <- coef(mod); se <- sqrt(diag(vcov(mod))); se_cl <- sqrt(diag(vcovCL(mod, cluster = cl)))
  tibble(termino = names(b), or = exp(b), inf = exp(b - 1.96 * se), sup = exp(b + 1.96 * se), inf_cl = exp(b - 1.96 * se_cl), sup_cl = exp(b + 1.96 * se_cl))
}
or_cl <- or_tab(glm_m, tr$GRUPO_CV)
glm_sin_dep <- glm(reformulate(setdiff(vars, "DEPARTAMENTO"), OBJ), data = prep(tr), family = binomial)
or_reg <- or_tab(glm_sin_dep, tr$GRUPO_CV) |> filter(str_detect(termino, "^REGION"))
write_csv(or_cl, file.path(RES, "13_odds_ratios_robustos.csv")); write_csv(or_reg, file.path(RES, "13_odds_ratios_region_sin_departamento.csv"))

# 5) Asignación con ajuste cruzado -------------------------------------------------------------------
gr <- unique(tr$GRUPO_CV); mitad <- sample(c(TRUE, FALSE), length(gr), replace = TRUE); names(mitad) <- gr
mA <- xgb_fit(tr[mitad[tr$GRUPO_CV], ]); mB <- xgb_fit(tr[!mitad[tr$GRUPO_CV], ])
cand <- which(y == 0 & te$ASOCIADO == 0)
ganancia <- function(mod) { dd <- te; dd$ASOCIADO <- 1; list(p = xgb_p(mod, te), g = xgb_p(mod, dd) - xgb_p(mod, te)) }
GA <- ganancia(mA); GB <- ganancia(mB); G0 <- ganancia(booster)
valor <- function(idx, K, sel, ev) {
  idx <- idx[idx %in% cand]; c(ganancia = sum(ev$g[idx][order(-sel$g[idx])][seq_len(min(K, length(idx)))]),
                               probabilidad = sum(ev$g[idx][order(-sel$p[idx])][seq_len(min(K, length(idx)))]),
                               azar = min(K, length(idx)) * mean(ev$g[idx]))
}
cruzado <- function(idx, K) (valor(idx, K, GA, GB) + valor(idx, K, GB, GA)) / 2
asig <- map_dfr(c(500, 1000, 2000), function(K) {
  pt <- cruzado(seq_len(nrow(te)), K); mismo <- valor(seq_len(nrow(te)), K, G0, G0)
  bsK <- replicate(B, cruzado(remuestra(), K))
  dif <- bsK["ganancia", ] - bsK["probabilidad", ]
  tibble(K = K, regla = c("ganancia", "probabilidad", "azar"), cruzado = pt, inf = apply(bsK, 1, q)[1, ], sup = apply(bsK, 1, q)[2, ],
         mismo_modelo = mismo, dif_ganancia_vs_prob = pt["ganancia"] - pt["probabilidad"], dif_inf = q(dif)[1], dif_sup = q(dif)[2])
})
sel1000 <- cand[order(-GA$g[cand])][1:1000]
comp_reg <- tibble(region = as.character(te$REGION[sel1000])) |> count(region) |> mutate(pct = 100 * n / sum(n))
write_csv(asig, file.path(RES, "13_asignacion_cruzada.csv")); write_csv(comp_reg, file.path(RES, "13_asignacion_region.csv"))

# 6) Comprobación con los 196,566 productores depurados ------------------------------------------------
lim <- read_parquet(file.path(RAIZ, "data", "etapas", "08_limpio.parquet")) |> as_tibble() |>
  mutate(REGION = factor(REGION, levels = 1:3, labels = c("Costa", "Sierra", "Selva")),
         DEPARTAMENTO = factor(DEPARTAMENTOS[as.character(DEPARTAMENTO)], levels = levels(d$DEPARTAMENTO)),
         across(where(is.numeric) & !c(FACTOR_EXP), as.numeric))
stopifnot(nrow(lim) == 196566, !anyNA(lim[, vars]))
pl <- groupKFold(lim$GRUPO_CV, k = 5); oof <- numeric(nrow(lim)); t0 <- Sys.time()
for (k in seq_along(pl)) { ent <- pl[[k]]; val <- setdiff(seq_len(nrow(lim)), ent); oof[val] <- xgb_p(xgb_fit(lim[ent, ]), lim[val, ]) }
min_full <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
yl <- lim[[OBJ]]; cl_l <- split(seq_len(nrow(lim)), lim$GRUPO_CV)
bsl <- replicate(300, { i <- unlist(cl_l[sample(length(cl_l), replace = TRUE)], use.names = FALSE); c(auc_roc(yl[i], oof[i]), auc_pr(yl[i], oof[i])) })
completo <- tibble(n = nrow(lim), conglomerados = length(cl_l), minutos = min_full, auc_roc = auc_roc(yl, oof), auc_roc_inf = q(bsl[1, ])[1], auc_roc_sup = q(bsl[1, ])[2],
                   auc_pr = auc_pr(yl, oof), auc_pr_inf = q(bsl[2, ])[1], auc_pr_sup = q(bsl[2, ])[2], azar = mean(yl),
                   brecha_pct = 100 * mean(oof >= u & yl == 0), predicha_media = 100 * mean(oof), observada = 100 * mean(yl))
lim$brecha <- as.integer(oof >= u & yl == 0)
dep_full <- lim |> filter(!is.na(DEPARTAMENTO), DEPARTAMENTO != "Callao") |> group_by(DEPARTAMENTO) |> group_modify(function(x, k) {
  cl <- split(seq_len(nrow(x)), x$GRUPO_CV)
  bs <- replicate(300, mean(x$brecha[unlist(cl[sample(length(cl), replace = TRUE)], use.names = FALSE)]))
  tibble(n = nrow(x), conglomerados = length(cl), tasa_credito = 100 * mean(x[[OBJ]]), brecha = 100 * mean(x$brecha), inf = 100 * q(bs)[1], sup = 100 * q(bs)[2])
}) |> ungroup() |> arrange(desc(brecha))
cmp <- dep |> select(DEPARTAMENTO, potencial) |> mutate(DEPARTAMENTO = as.character(DEPARTAMENTO)) |>
  inner_join(dep_full |> mutate(DEPARTAMENTO = as.character(DEPARTAMENTO)) |> select(DEPARTAMENTO, brecha), by = "DEPARTAMENTO")
completo$spearman_dptos_vs_prueba <- cor(cmp$potencial, cmp$brecha, method = "spearman")
completo$spearman_tasa_vs_brecha <- cor(dep_full$tasa_credito, dep_full$brecha, method = "spearman")
write_csv(completo, file.path(RES, "13_datos_completos.csv")); write_csv(dep_full, file.path(RES, "13_departamentos_datos_completos.csv"))

cat("\n== Modelos ==\n"); print(bench, width = 250)
cat("\n== Solicitud ==\n"); print(sol); cat("Spearman tasa vs potencial por dpto (prueba):", round(corr_dep, 3), "\n")
cat("\n== Sensibilidad al umbral ==\n"); print(sens)
cat("\n== Ponderado ==\n"); print(obs); print(pond)
cat("\n== OR robustos ==\n"); print(or_cl |> filter(!str_detect(termino, "DEPARTAMENTO")), width = 200); print(or_reg)
cat("\n== Asignación (ajuste cruzado) ==\n"); print(asig, width = 200); print(comp_reg)
cat("\n== Datos completos ==\n"); print(completo, width = 250); print(dep_full, n = 30)
