# 18 · Análisis pedidos por los revisores de ICALTER 2026 (versión final del artículo).
#   1) Validación temporal por ronda: (a) hacia adelante, entrenando solo con rondas anteriores y evaluando una ronda completa;
#      (b) dejando fuera cada ronda. AUC con IC bootstrap por conglomerado y calibración global (predicho frente a observado).
#   2) Equidad regional en el conjunto de prueba: AUC, calibración y tasa predicha frente a observada por región natural.
#   3) Asignación con presupuesto y costos: promover la asociatividad entre no asociados sin crédito. Costo por productor
#      ilustrativo (costa 1, sierra 1.5, selva 2 unidades); reglas: ganancia/costo, ganancia, probabilidad y azar,
#      evaluadas con ajuste cruzado (un modelo elige, otro independiente evalúa), con IC bootstrap.
# Uso: Rscript R/18_revisores.R   (~2 min)
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(xgboost) })
set.seed(SEMILLA)
B <- as.integer(Sys.getenv("N_BOOT", "300"))
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
vars <- m$vars; booster <- m$ajuste$finalModel$booster; bt <- m$ajuste$bestTune
xgb_fit <- function(dd) xgb.train(list(objective = "binary:logistic", eta = bt$eta, max_depth = bt$max_depth, min_child_weight = bt$min_child_weight,
                                       subsample = bt$subsample, colsample_bytree = bt$colsample_bytree, gamma = bt$gamma, lambda = bt$lambda,
                                       alpha = bt$alpha, nthread = 12), xgb.DMatrix(matriz(dd, vars), label = dd[[OBJ]]), nrounds = bt$nrounds, verbose = 0)
xgb_p <- function(b, dd) predict(b, xgb.DMatrix(matriz(dd, vars)))
q <- function(x) unname(quantile(x, c(0.025, 0.975), na.rm = TRUE))
boot_auc <- function(y, p, g) {
  cl <- split(seq_along(y), g)
  bs <- replicate(B, { i <- unlist(cl[sample(length(cl), replace = TRUE)], use.names = FALSE); if (length(unique(y[i])) < 2) NA else auc_roc(y[i], p[i]) })
  q(bs)
}

# 1) Validación por ronda ---------------------------------------------------------------------------
rondas <- sort(unique(d$ANIO))
por_ronda <- map_dfr(rondas, function(r) {
  ev <- filter(d, ANIO == r); y <- ev[[OBJ]]
  loro <- xgb_p(xgb_fit(filter(d, ANIO != r)), ev); ic <- boot_auc(y, loro, ev$GRUPO_CV)
  fila <- tibble(ronda = r, n = nrow(ev), prevalencia = 100 * mean(y),
                 loro_auc = auc_roc(y, loro), loro_inf = ic[1], loro_sup = ic[2], loro_pred = 100 * mean(loro))
  ant <- filter(d, ANIO < r)
  if (nrow(ant) > 0 && r > min(rondas)) {
    adel <- xgb_p(xgb_fit(ant), ev); ic2 <- boot_auc(y, adel, ev$GRUPO_CV)
    fila <- fila |> mutate(adel_entren = paste(range(ant$ANIO), collapse = "-"), adel_auc = auc_roc(y, adel), adel_inf = ic2[1], adel_sup = ic2[2],
                           adel_pr = auc_pr(y, adel), adel_pred = 100 * mean(adel))
  }
  fila
})
write_csv(por_ronda, file.path(RES, "18_validacion_por_ronda.csv"))

# 2) Equidad regional (prueba) ------------------------------------------------------------------------
te <- filter(d, CONJUNTO == "prueba"); tr <- filter(d, CONJUNTO == "entrenamiento"); y <- te[[OBJ]]
te$p <- xgb_p(booster, te)
equidad <- te |> mutate(region = as.character(REGION)) |> group_by(region) |>
  group_modify(~ { ic <- boot_auc(.x[[OBJ]], .x$p, .x$GRUPO_CV)
    tibble(n = nrow(.x), observada = 100 * mean(.x[[OBJ]]), predicha = 100 * mean(.x$p), auc = auc_roc(.x[[OBJ]], .x$p), auc_inf = ic[1], auc_sup = ic[2],
           recall = 100 * mean(.x$p[.x[[OBJ]] == 1] >= m$umbral), ppos = 100 * mean(.x$p >= m$umbral)) }) |> ungroup()
write_csv(equidad, file.path(RES, "18_equidad_region.csv"))

# 3) Asignación con costos ---------------------------------------------------------------------------
COSTO <- c(Costa = 1, Sierra = 1.5, Selva = 2)
# El resultado depende de cómo se parte el entrenamiento en dos mitades, así que se repite con R particiones y se promedia.
R_PART <- as.integer(Sys.getenv("N_PARTICIONES", "5"))
ganancia <- function(mod) { dd <- te; dd$ASOCIADO <- 1; list(p = xgb_p(mod, te), g = xgb_p(mod, dd) - xgb_p(mod, te)) }
gr <- unique(tr$GRUPO_CV)
PARES <- map(seq_len(R_PART), function(k) {
  mitad <- sample(c(TRUE, FALSE), length(gr), replace = TRUE); names(mitad) <- gr
  list(A = ganancia(xgb_fit(tr[mitad[tr$GRUPO_CV], ])), B = ganancia(xgb_fit(tr[!mitad[tr$GRUPO_CV], ])))
})
cand <- which(y == 0 & te$ASOCIADO == 0)
reg <- as.character(te$REGION)
elegir <- function(idx, orden, costo, presupuesto) { o <- idx[orden]; o[cumsum(costo[o]) <= presupuesto] }
valor <- function(idx, presupuesto, costo, sel, ev) {
  idx <- idx[idx %in% cand]
  reglas <- list(ganancia_costo = order(-sel$g[idx] / costo[idx]), ganancia = order(-sel$g[idx]), probabilidad = order(-sel$p[idx]))
  r <- map(reglas, ~ elegir(idx, .x, costo, presupuesto))
  out <- map_dbl(r, ~ sum(ev$g[.x]))
  azar <- presupuesto / mean(costo[idx]) * mean(ev$g[idx])
  list(nuevos = c(out, azar = azar), n = c(map_int(r, length), azar = presupuesto / mean(costo[idx])),
       region = map(r, ~ table(factor(reg[.x], levels = names(COSTO)))))
}
cruz <- function(idx, P, costo) {
  res <- unlist(map(PARES, ~ list(valor(idx, P, costo, .x$A, .x$B), valor(idx, P, costo, .x$B, .x$A))), recursive = FALSE)
  list(nuevos = Reduce(`+`, map(res, "nuevos")) / length(res), n = Reduce(`+`, map(res, "n")) / length(res),
       region = Reduce(function(a, b) map2(a, b, `+`), map(res, "region")))
}
clus <- split(seq_len(nrow(te)), te$GRUPO_CV)
remuestra <- function() unlist(clus[sample(length(clus), replace = TRUE)], use.names = FALSE)
escenarios_costo <- list(uniforme = setNames(rep(1, nrow(te)), NULL), regional = unname(COSTO[reg]))
P <- 1000
asig_costo <- map_dfr(names(escenarios_costo), function(es) {
  costo <- escenarios_costo[[es]]; pt <- cruz(seq_len(nrow(te)), P, costo)
  bs <- replicate(B, cruz(remuestra(), P, costo)$nuevos)
  reg_tab <- map_dfr(pt$region, ~ as_tibble(as.list(100 * .x / sum(.x))), .id = "regla")
  tibble(costos = es, presupuesto = P, regla = names(pt$nuevos), productores = pt$n, nuevos = pt$nuevos,
         inf = apply(bs, 1, q)[1, ], sup = apply(bs, 1, q)[2, ], costo_por_nuevo = P / pt$nuevos) |>
    left_join(reg_tab, by = "regla")
})
cand_reg <- 100 * prop.table(table(factor(reg[cand], levels = names(COSTO))))
write_csv(asig_costo, file.path(RES, "18_asignacion_costos.csv"))
write_csv(as_tibble(as.list(cand_reg)), file.path(RES, "18_candidatos_region.csv"))

cat("\n== Validación por ronda ==\n"); print(por_ronda, width = 200)
cat("\n== Equidad regional ==\n"); print(equidad, width = 200)
cat("\n== Asignación con costos (presupuesto", P, "unidades) ==\n"); print(asig_costo, width = 200)
cat("\nCandidatos por región (%):\n"); print(round(cand_reg, 1))

# Tabla para el dashboard: misma asignación (costo uniforme, presupuesto = productores atendidos) con 500, 1000 y 2000.
asig_k <- map_dfr(c(500, 1000, 2000), function(K) {
  uno <- escenarios_costo$uniforme; pt <- cruz(seq_len(nrow(te)), K, uno)
  bs <- replicate(B, cruz(remuestra(), K, uno)$nuevos)
  sr <- map_dbl(pt$region, ~ 100 * sum(.x[c("Sierra", "Selva")]) / sum(.x))
  tibble(K = K, regla = names(pt$nuevos), cruzado = pt$nuevos, inf = apply(bs, 1, q)[1, ], sup = apply(bs, 1, q)[2, ],
         pct_sierra_selva = c(sr[c("ganancia_costo", "ganancia", "probabilidad")], azar = sum(cand_reg[c("Sierra", "Selva")]))[names(pt$nuevos)]) |>
    filter(regla != "ganancia_costo")
})
write_csv(asig_k, file.path(RES, "18_asignacion_k.csv"))
cat("\n== Asignación por tamaño del programa (costo uniforme) ==\n"); print(asig_k, width = 200)
