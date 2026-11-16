# 05 · Evaluación en el conjunto de prueba (no usado en ningún paso anterior).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost); library(pROC); library(PRROC) })
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
te <- d |> filter(CONJUNTO == "prueba")
y <- te[[OBJ]]; u <- m$umbral
p <- predict(m$ajuste, matriz(te, m$vars), type = "prob")$Si
saveRDS(tibble(K_PROD = te$K_PROD, ANIO = te$ANIO, y = y, p = p), file.path(DATOS, "predicciones_prueba.rds"))

met <- metricas(y, p, u)
azar <- metricas(y, rep(mean(d[[OBJ]][d$CONJUNTO == "entrenamiento"]), length(y)), u)
tabla <- tibble(metrica = names(met), xgboost = round(met, 4), azar = round(azar, 4))
write_csv(tabla, file.path(RES, "05_metricas_prueba.csv"))

# Matriz de confusión con caret
cm <- confusionMatrix(factor(if_else(p >= u, "Si", "No"), levels = c("No", "Si")), factor(if_else(y == 1, "Si", "No"), levels = c("No", "Si")), positive = "Si")
write_csv(as_tibble(cm$table) |> rename(prediccion = Prediction, real = Reference, n = n), file.path(RES, "05_matriz_confusion.csv"))

# Por año y por región
por_grupo <- bind_rows(
  te |> mutate(p = p) |> group_by(valor = as.character(ANIO)) |> group_modify(~ as_tibble_row(c(n = nrow(.x), prevalencia = 100 * mean(.x[[OBJ]]), metricas(.x[[OBJ]], .x$p, u)))) |> mutate(grupo = "Año"),
  te |> mutate(p = p) |> group_by(valor = as.character(REGION)) |> group_modify(~ as_tibble_row(c(n = nrow(.x), prevalencia = 100 * mean(.x[[OBJ]]), metricas(.x[[OBJ]], .x$p, u)))) |> mutate(grupo = "Región")) |>
  ungroup() |> relocate(grupo)
write_csv(por_grupo, file.path(RES, "05_metricas_grupo.csv"))

# Calibración por deciles
cal <- tibble(y = y, p = p) |> mutate(decil = ntile(p, 10)) |> group_by(decil) |> summarise(predicha = 100 * mean(p), real = 100 * mean(y), n = n())
write_csv(cal, file.path(RES, "05_calibracion.csv"))

# Curvas
roc_o <- roc(y, p, quiet = TRUE, direction = "<")
roc_df <- tibble(fpr = 1 - roc_o$specificities, tpr = roc_o$sensitivities) |> arrange(fpr, tpr)
pr_o <- pr.curve(scores.class0 = p[y == 1], scores.class1 = p[y == 0], curve = TRUE)
pr_df <- as_tibble(pr_o$curve[, 1:2], .name_repair = ~ c("recall", "precision"))
yh <- p >= u; pt <- c(fpr = sum(yh & y == 0) / sum(y == 0), tpr = sum(yh & y == 1) / sum(y == 1), prec = sum(yh & y == 1) / sum(yh))
g1 <- ggplot(roc_df, aes(fpr, tpr)) + geom_abline(linetype = "dashed", colour = GRIS) + geom_line(colour = VERDE, linewidth = 1) +
  annotate("point", x = pt["fpr"], y = pt["tpr"], colour = NARANJA, size = 3.5) +
  labs(x = "Falsos positivos", y = "Sensibilidad", title = sprintf("ROC · AUC = %.3f", met["AUC-ROC"])) + coord_equal() + tema()
g2 <- ggplot(pr_df, aes(recall, precision)) + geom_hline(yintercept = mean(y), linetype = "dashed", colour = GRIS) +
  geom_line(colour = AZUL, linewidth = 1) + annotate("point", x = pt["tpr"], y = pt["prec"], colour = NARANJA, size = 3.5) +
  labs(x = "Recall", y = "Precisión", title = sprintf("Precisión–recall · AUC-PR = %.3f (azar %.3f)", met["AUC-PR"], mean(y))) + ylim(0, 1) + tema()
g3 <- ggplot(cal, aes(predicha, real)) + geom_abline(linetype = "dashed", colour = GRIS) + geom_line(colour = VERDE) + geom_point(colour = VERDE, size = 2.5) +
  labs(x = "Probabilidad predicha (%)", y = "Con crédito real (%)", title = "Calibración por deciles") + tema()
guardar(patchwork::wrap_plots(g1, g2, g3, nrow = 1), "05_curvas.png", 13, 4.3)

print(tabla, n = 20); print(cm$table); print(por_grupo |> select(grupo, valor, n, prevalencia, `AUC-ROC`, `AUC-PR`, `F1 (con crédito)`, MCC)); print(cal)
