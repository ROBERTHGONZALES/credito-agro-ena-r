# 03 · Selección de variables en R, usando SOLO el conjunto de entrenamiento.
#   1. Importancia: media de |SHAP| de XGBoost en validación cruzada de 5 pliegues agrupada por conglomerado (caret::groupKFold).
#   2. Redundancia: en cada par con |Spearman| >= 0.70 (easystats::correlation) se elimina el de menor importancia.
#   3. Curva: AUC-PR en la misma validación con las k primeras variables. Regla de un error estándar:
#      se elige el menor k cuyo AUC-PR está a menos de un error estándar del máximo (modelo más simple sin pérdida).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost); library(correlation) })
set.seed(SEMILLA)
d <- cargar() |> filter(CONJUNTO == "entrenamiento")
y <- d[[OBJ]]
pred <- predictores_todos(d)
pliegues <- groupKFold(d$GRUPO_CV, k = 5)                       # índices de entrenamiento de cada pliegue
PARAMS <- list(objective = "binary:logistic", eval_metric = "aucpr", eta = 0.03, max_depth = 6, min_child_weight = 10,
               subsample = 0.8, colsample_bytree = 0.8, lambda = 1, nthread = 12)
NRONDAS <- 400

cv <- function(vars, con_shap = FALSE) {
  X <- matriz(d, vars); grupo <- attr(X, "variable")
  res <- lapply(pliegues, function(tr) {
    va <- setdiff(seq_len(nrow(d)), tr)
    m <- xgb.train(PARAMS, xgb.DMatrix(X[tr, , drop = FALSE], label = y[tr]), nrounds = NRONDAS, verbose = 0)
    dv <- xgb.DMatrix(X[va, , drop = FALSE])
    p <- predict(m, dv)
    out <- list(pr = auc_pr(y[va], p), roc = auc_roc(y[va], p))
    if (con_shap) {
      s <- predict(m, dv, predcontrib = TRUE)[, seq_len(ncol(X)), drop = FALSE]
      out$shap <- vapply(vars, function(v) mean(abs(rowSums(s[, grupo == v, drop = FALSE]))), 0)   # dummies → variable original
    }
    out
  })
  list(pr = vapply(res, `[[`, 0, "pr"), roc = vapply(res, `[[`, 0, "roc"), shap = if (con_shap) rowMeans(sapply(res, `[[`, "shap")))
}

# 1 · Importancia SHAP con las 35 candidatas
t0 <- Sys.time()
base <- cv(pred, con_shap = TRUE)
ranking <- tibble(variable = pred, shap = base$shap) |> arrange(desc(shap)) |> mutate(puesto = row_number())
cat(sprintf("35 variables: AUC-PR CV %.4f ± %.4f\n", mean(base$pr), sd(base$pr)))

# 2 · Redundancia
num <- pred[vapply(d[pred], is.numeric, TRUE)]
pares <- correlation(d[num], method = "spearman", p_adjust = "none") |> as_tibble() |>
  filter(abs(rho) >= 0.70) |> transmute(var_1 = Parameter1, var_2 = Parameter2, spearman = round(rho, 3)) |> arrange(desc(abs(spearman)))
imp <- deframe(ranking[c("variable", "shap")])
eliminadas <- character(); motivo <- character()
for (v in ranking$variable) {                                    # de mayor a menor importancia
  if (v %in% eliminadas) next
  socios <- c(pares$var_2[pares$var_1 == v], pares$var_1[pares$var_2 == v])
  for (s in setdiff(socios, eliminadas)) if (imp[[s]] < imp[[v]]) { eliminadas <- c(eliminadas, s); motivo[s] <- v }
}
pares <- pares |> mutate(se_elimina = if_else(imp[var_1] < imp[var_2], var_1, var_2))
orden <- setdiff(ranking$variable, eliminadas)
cat("Redundantes eliminadas:", paste(eliminadas, collapse = ", "), "\n")

# 3 · Curva de desempeño
ks <- sort(unique(c(5, 8, 10, 12, 14, 15, 16, 17, 18, 19, 20, 22, 25, length(orden))))
curva <- map_dfr(ks, function(k) {
  r <- cv(orden[seq_len(k)])
  cat(sprintf("k = %2d  AUC-PR %.4f ± %.4f  AUC-ROC %.4f\n", k, mean(r$pr), sd(r$pr), mean(r$roc)))
  tibble(k = k, auc_pr = mean(r$pr), auc_pr_sd = sd(r$pr), auc_pr_ee = sd(r$pr) / sqrt(5), auc_roc = mean(r$roc))
})
mejor <- curva[which.max(curva$auc_pr), ]
k_elegido <- min(curva$k[curva$auc_pr >= mejor$auc_pr - mejor$auc_pr_ee])
curva <- curva |> mutate(elegido = k == k_elegido)
cat(sprintf("Máximo: k = %d (%.4f). Regla de un error estándar → k = %d\n", mejor$k, mejor$auc_pr, k_elegido))

seleccion <- ranking |> mutate(
  etiqueta = ETIQUETAS[variable],
  seleccionada = as.integer(variable %in% orden[seq_len(k_elegido)]),
  motivo = case_when(seleccionada == 1 ~ "seleccionada",
                     variable %in% eliminadas ~ paste0("redundante con ", motivo[variable]),
                     TRUE ~ paste0("fuera de las ", k_elegido, " primeras"))) |>
  select(puesto, variable, etiqueta, shap, seleccionada, motivo)
write_csv(seleccion, file.path(RES, "03_variables.csv"))
write_csv(pares, file.path(RES, "03_pares_redundantes.csv"))
write_csv(curva, file.path(RES, "03_curva_variables.csv"))
saveRDS(orden[seq_len(k_elegido)], file.path(DATOS, "variables.rds"))

g1 <- ggplot(seleccion, aes(shap, reorder(etiqueta, shap), fill = factor(seleccionada))) + geom_col(width = 0.7) +
  scale_fill_manual(values = c("0" = "#cbd5e1", "1" = VERDE), labels = c("No", "Sí"), name = "En el modelo") +
  labs(x = "Importancia media |SHAP| (validación cruzada)", y = NULL, title = "Importancia de las 35 variables candidatas") +
  tema() + theme(legend.position = c(0.8, 0.15), axis.text.y = element_text(size = 8))
g2 <- ggplot(curva, aes(k, auc_pr)) +
  geom_hline(yintercept = mejor$auc_pr - mejor$auc_pr_ee, linetype = "dashed", colour = GRIS) +
  geom_errorbar(aes(ymin = auc_pr - auc_pr_ee, ymax = auc_pr + auc_pr_ee), width = 0.4, colour = GRIS) +
  geom_line(colour = AZUL, linewidth = 0.9) + geom_point(aes(colour = elegido, size = elegido)) +
  scale_colour_manual(values = c("FALSE" = AZUL, "TRUE" = NARANJA), guide = "none") + scale_size_manual(values = c(2.2, 4.5), guide = "none") +
  labs(x = "Número de variables", y = "AUC-PR (validación cruzada)", title = sprintf("Curva de desempeño: se eligen %d variables", k_elegido),
       subtitle = "Barras: ± 1 error estándar") + tema()
guardar(patchwork::wrap_plots(g1, g2, widths = c(1.1, 1)), "03_seleccion.png", 12, 5.6)
print(seleccion, n = 35)
cat(sprintf("Tiempo: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
