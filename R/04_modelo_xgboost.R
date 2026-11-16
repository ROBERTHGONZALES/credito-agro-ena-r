# 04 · XGBoost con caret: búsqueda aleatoria de hiperparámetros con validación cruzada de 5 pliegues
#      agrupada por conglomerado (métrica: AUC-PR) y umbral que maximiza F1 en las predicciones fuera de muestra.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost) })
set.seed(SEMILLA)
N_COMB <- as.integer(Sys.getenv("N_COMB", "40"))
d <- cargar(); vars <- readRDS(file.path(DATOS, "variables.rds"))
tr <- d |> filter(CONJUNTO == "entrenamiento")
X <- matriz(tr, vars)
y <- factor(if_else(tr[[OBJ]] == 1, "Si", "No"), levels = c("No", "Si"))

# Método propio de caret para XGBoost (misma interfaz de caret::train; incluye regularización L1 y L2)
xgb_caret <- list(
  label = "XGBoost", library = "xgboost", type = "Classification",
  parameters = data.frame(parameter = c("nrounds", "eta", "max_depth", "min_child_weight", "subsample", "colsample_bytree", "gamma", "lambda", "alpha"),
                          class = "numeric", label = c("Árboles", "Tasa de aprendizaje", "Profundidad", "Peso mínimo por hoja", "Submuestreo de filas",
                                                       "Submuestreo de columnas", "Gamma", "L2", "L1")),
  grid = function(x, y, len = NULL, search = "random") NULL,
  fit = function(x, y, wts, param, lev, last, classProbs, ...) {
    list(booster = xgb.train(list(objective = "binary:logistic", eval_metric = "aucpr", eta = param$eta, max_depth = param$max_depth,
                   min_child_weight = param$min_child_weight, subsample = param$subsample, colsample_bytree = param$colsample_bytree,
                   gamma = param$gamma, lambda = param$lambda, alpha = param$alpha, nthread = 12),
              xgb.DMatrix(as.matrix(x), label = as.integer(y == lev[2])), nrounds = param$nrounds, verbose = 0))   # en una lista: caret añade campos al objeto
  },
  predict = function(modelFit, newdata, submodels = NULL) {
    p <- predict(modelFit$booster, xgb.DMatrix(as.matrix(newdata))); factor(ifelse(p >= 0.5, modelFit$obsLevels[2], modelFit$obsLevels[1]), levels = modelFit$obsLevels)
  },
  prob = function(modelFit, newdata, submodels = NULL) {
    p <- predict(modelFit$booster, xgb.DMatrix(as.matrix(newdata))); out <- data.frame(1 - p, p); names(out) <- modelFit$obsLevels; out
  },
  levels = function(x) x$obsLevels, sort = function(x) x[order(x$nrounds, x$max_depth), ])

resumen_cv <- function(data, lev = NULL, model = NULL) {
  yy <- as.integer(data$obs == "Si")
  c(AUC_PR = auc_pr(yy, data$Si), AUC_ROC = auc_roc(yy, data$Si))
}

rejilla <- tibble(
  nrounds = round(runif(N_COMB, 150, 800)), eta = round(exp(runif(N_COMB, log(0.01), log(0.10))), 4),
  max_depth = sample(3:9, N_COMB, replace = TRUE), min_child_weight = round(exp(runif(N_COMB, log(1), log(60))), 1),
  subsample = round(runif(N_COMB, 0.6, 1), 2), colsample_bytree = round(runif(N_COMB, 0.5, 1), 2),
  gamma = round(runif(N_COMB, 0, 5), 2), lambda = round(exp(runif(N_COMB, log(0.1), log(10))), 2), alpha = round(exp(runif(N_COMB, log(0.001), log(1))), 3))

pliegues <- groupKFold(tr$GRUPO_CV, k = 5)
control <- trainControl(method = "cv", index = pliegues, classProbs = TRUE, summaryFunction = resumen_cv,
                        savePredictions = "final", allowParallel = FALSE, verboseIter = FALSE)
t0 <- Sys.time()
ajuste <- train(x = X, y = y, method = xgb_caret, trControl = control, tuneGrid = as.data.frame(rejilla), metric = "AUC_PR", maximize = TRUE)
minutos <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

busqueda <- as_tibble(ajuste$results) |> arrange(desc(AUC_PR))
write_csv(busqueda, file.path(RES, "04_busqueda.csv"))
oof <- ajuste$pred |> arrange(rowIndex)                         # predicciones fuera de muestra de la mejor combinación
y_tr <- as.integer(oof$obs == "Si")
umbral <- umbral_f1(y_tr, oof$Si)
estab <- oof |> group_by(Resample) |> group_modify(~ as_tibble_row(metricas(as.integer(.x$obs == "Si"), .x$Si, umbral))) |> ungroup()
p_tr <- predict(ajuste, X, type = "prob")$Si

saveRDS(list(ajuste = ajuste, umbral = umbral, vars = vars, minutos = minutos), file.path(DATOS, "modelo_xgboost.rds"))
write_csv(estab, file.path(RES, "04_estabilidad_cv.csv"))
info <- tibble(combinaciones = N_COMB, minutos = round(minutos, 1), umbral = umbral,
               cv_auc_pr = busqueda$AUC_PR[1], cv_auc_pr_sd = busqueda$AUC_PRSD[1], cv_auc_roc = busqueda$AUC_ROC[1], cv_auc_roc_sd = busqueda$AUC_ROCSD[1],
               train_auc_pr = auc_pr(as.integer(y == "Si"), p_tr), train_auc_roc = auc_roc(as.integer(y == "Si"), p_tr)) |> bind_cols(ajuste$bestTune)
write_csv(info, file.path(RES, "04_modelo.csv"))
cat(sprintf("%d combinaciones × 5 pliegues en %.1f min\n", N_COMB, minutos))
print(head(busqueda, 8), width = 200); print(t(info))
