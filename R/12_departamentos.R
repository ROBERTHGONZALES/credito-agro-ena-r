# 12 · Resultados por departamento con su incertidumbre.
#   - Prueba (9,969): tasa de crédito y % de demanda potencial (sin crédito y p >= umbral) por departamento,
#     con intervalos bootstrap del 95 % remuestreando conglomerados dentro de cada departamento.
#   - Comprobación con toda la muestra (49,837): predicciones fuera de muestra (fuera de pliegue para el
#     entrenamiento, modelo final para la prueba), que multiplican por cinco los productores por departamento.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost) })
set.seed(SEMILLA)
B <- as.integer(Sys.getenv("N_BOOT", "1000"))
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds")); u <- m$umbral
booster <- m$ajuste$finalModel$booster
tr <- d |> filter(CONJUNTO == "entrenamiento"); te <- d |> filter(CONJUNTO == "prueba")
te$p <- predict(booster, xgb.DMatrix(matriz(te, m$vars)))
oof <- m$ajuste$pred |> arrange(rowIndex); stopifnot(nrow(oof) == nrow(tr))
tr$p <- oof$Si
todo <- bind_rows(tr, te) |> mutate(potencial = as.integer(p >= u & .data[[OBJ]] == 0))
te <- te |> mutate(potencial = as.integer(p >= u & .data[[OBJ]] == 0))

ic_dep <- function(dd) {
  dd |> group_by(DEPARTAMENTO) |> group_modify(function(x, k) {
    cl <- split(seq_len(nrow(x)), x$GRUPO_CV)
    bs <- replicate(B, { i <- unlist(cl[sample(length(cl), replace = TRUE)], use.names = FALSE); c(mean(x$potencial[i]), mean(x[[OBJ]][i])) })
    tibble(n = nrow(x), conglomerados = length(cl), tasa_credito = 100 * mean(x[[OBJ]]),
           cred_inf = 100 * quantile(bs[2, ], 0.025), cred_sup = 100 * quantile(bs[2, ], 0.975),
           potencial = 100 * mean(x$potencial), pot_inf = 100 * quantile(bs[1, ], 0.025), pot_sup = 100 * quantile(bs[1, ], 0.975))
  }) |> ungroup() |> arrange(desc(potencial)) |> mutate(puesto = row_number())
}
dep_te <- ic_dep(te)
dep_todo <- ic_dep(filter(todo, DEPARTAMENTO %in% unique(te$DEPARTAMENTO)))   # el Callao tiene un solo productor (en entrenamiento)
write_csv(dep_te, file.path(RES, "12_departamentos_prueba.csv"))
write_csv(dep_todo, file.path(RES, "12_departamentos_muestra_completa.csv"))
comp <- dep_te |> select(DEPARTAMENTO, puesto_prueba = puesto, pot_prueba = potencial) |>
  left_join(dep_todo |> select(DEPARTAMENTO, puesto_todo = puesto, pot_todo = potencial), by = "DEPARTAMENTO")
cat("Correlación de Spearman entre los dos órdenes:", round(cor(comp$puesto_prueba, comp$puesto_todo, method = "spearman"), 3), "\n")
cat("Demanda potencial total en la muestra completa:", round(100 * mean(todo$potencial), 1), "%\n")
print(dep_te, n = 30, width = 200); print(comp, n = 30)
