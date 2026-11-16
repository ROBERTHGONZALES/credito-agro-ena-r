# 06 · Interpretación con SHAP (shapviz) sobre el conjunto de prueba y efectos en puntos porcentuales.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost); library(shapviz) })
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
te <- d |> filter(CONJUNTO == "prueba"); vars <- m$vars
X <- matriz(te, vars); grupo <- attr(X, "variable")
booster <- m$ajuste$finalModel$booster

# Valores SHAP exactos (TreeSHAP); las columnas 0/1 de cada variable categórica se suman en una sola
colapsar <- lapply(set_names(intersect(vars, CATEGORICAS)), function(v) colnames(X)[grupo == v])
Xdf <- te[vars] |> mutate(across(where(is.factor), as.character)) |> as.data.frame()
sv <- shapviz(booster, X_pred = X, X = Xdf, collapse = colapsar)
S <- get_shap_values(sv)
imp <- tibble(variable = colnames(S), etiqueta = ETIQUETAS[colnames(S)], shap = colMeans(abs(S))) |> arrange(desc(shap))
write_csv(imp, file.path(RES, "06_importancia_shap.csv"))

# Efecto en puntos porcentuales (dependencia parcial): binarias de No a Sí; numéricas del percentil 25 al 75
prob <- function(dd) predict(booster, xgb.DMatrix(matriz(dd, vars)))
efectos <- map_dfr(setdiff(vars, CATEGORICAS), function(v) {
  x <- te[[v]]; bin <- n_distinct(d[[v]]) == 2
  a <- if (bin) 0 else unname(quantile(d[[v]][d$CONJUNTO == "entrenamiento"], 0.25)); b <- if (bin) 1 else unname(quantile(d[[v]][d$CONJUNTO == "entrenamiento"], 0.75))
  if (a == b) return(NULL)
  da <- te; da[[v]] <- a; db <- te; db[[v]] <- b
  tibble(variable = v, etiqueta = ETIQUETAS[[v]], tipo = if (bin) "No → Sí" else sprintf("%s → %s (p25 → p75)", format(a, digits = 3), format(b, digits = 3)),
         efecto_pp = 100 * (mean(prob(db)) - mean(prob(da))))
}) |> arrange(desc(efecto_pp))
write_csv(efectos, file.path(RES, "06_efectos_pp.csv"))

# Efecto propio de cada departamento y región (SHAP medio)
if ("DEPARTAMENTO" %in% vars) write_csv(tibble(departamento = te$DEPARTAMENTO, shap = S[, "DEPARTAMENTO"]) |> group_by(departamento) |>
                                          summarise(shap = mean(shap), n = n()) |> arrange(desc(shap)), file.path(RES, "06_shap_departamento.csv"))

g1 <- ggplot(imp, aes(shap, reorder(etiqueta, shap))) + geom_col(fill = VERDE, width = 0.7) +
  geom_text(aes(label = sprintf("%.3f", shap)), hjust = -0.15, size = 3.2) + scale_x_continuous(expand = expansion(mult = c(0.01, 0.14))) +
  labs(x = "Importancia media |SHAP| (log-odds)", y = NULL, title = "Importancia de las variables") + tema()
g2 <- ggplot(efectos, aes(efecto_pp, reorder(etiqueta, efecto_pp), fill = efecto_pp > 0)) + geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%+.1f", efecto_pp), hjust = if_else(efecto_pp > 0, -0.15, 1.15)), size = 3.2) +
  scale_fill_manual(values = c("TRUE" = AZUL, "FALSE" = NARANJA), guide = "none") + scale_x_continuous(expand = expansion(mult = 0.16)) +
  labs(x = "Cambio de probabilidad (puntos porcentuales)", y = NULL, title = "Efecto de cada factor") + tema()
guardar(patchwork::wrap_plots(g1, g2), "06_importancia_efectos.png", 12.5, 5)

top_num <- head(setdiff(imp$variable, c(CATEGORICAS, vars[vapply(te[vars], function(x) n_distinct(x) <= 2, TRUE)])), 6)
dep <- map(top_num, function(v) {
  dd <- tibble(x = te[[v]], s = S[, v]); if (grepl("SUP_", v)) dd <- dd |> filter(x > 0)
  g <- ggplot(dd, aes(x, s)) + geom_point(alpha = 0.08, size = 0.5, colour = GRIS) + geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), colour = NARANJA, se = FALSE, linewidth = 1) +
    geom_hline(yintercept = 0, linewidth = 0.3) + labs(x = ETIQUETAS[[v]], y = "SHAP") + tema()
  if (grepl("SUP_", v)) g <- g + scale_x_log10() else g <- g + coord_cartesian(xlim = quantile(dd$x, c(0.005, 0.995)))
  g
})
guardar(patchwork::wrap_plots(dep, ncol = 3), "06_dependencia.png", 12, 6.2)
guardar(sv_importance(sv, kind = "beeswarm", max_display = length(vars)) + tema(), "06_beeswarm.png", 8, 6)
print(imp, n = 30); print(efectos, n = 30)
