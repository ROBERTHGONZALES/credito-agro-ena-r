# 02 · Exploración: tasas de acceso a crédito ponderadas, descripción de variables y correlaciones (tidyverse + easystats).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(datawizard); library(correlation); library(effectsize) })
d <- cargar()
tasa <- function(x, w) 100 * weighted.mean(x, w)

# Tasas ponderadas con el factor de expansión de la muestra
por_anio <- d |> group_by(ANIO) |> summarise(productores = n(), tasa = tasa(ACCESO_CREDITO, FACTOR_EXP_MUESTRA))
por_region <- d |> group_by(REGION) |> summarise(productores = n(), tasa = tasa(ACCESO_CREDITO, FACTOR_EXP_MUESTRA))
por_depto <- d |> group_by(DEPARTAMENTO) |> summarise(productores = n(), tasa = tasa(ACCESO_CREDITO, FACTOR_EXP_MUESTRA)) |> arrange(desc(tasa))
write_csv(por_anio, file.path(RES, "02_tasa_anio.csv")); write_csv(por_region, file.path(RES, "02_tasa_region.csv"))
write_csv(por_depto, file.path(RES, "02_tasa_departamento.csv"))

# Descripción de las variables numéricas (datawizard)
pred <- predictores_todos(d)
num <- pred[vapply(d[pred], function(x) is.numeric(x) && n_distinct(x) > 2, TRUE)]
bin <- pred[vapply(d[pred], function(x) is.numeric(x) && n_distinct(x) == 2, TRUE)]
desc <- describe_distribution(d[num]) |> as_tibble() |> mutate(Etiqueta = ETIQUETAS[Variable], .after = Variable)
write_csv(desc, file.path(RES, "02_descripcion_numericas.csv"))

# Variables binarias: tasa de crédito cuando la característica está presente o ausente, y tamaño del efecto (V de Cramér)
bin_tab <- map_dfr(bin, function(v) {
  tibble(variable = v, etiqueta = ETIQUETAS[[v]], pct_si = 100 * weighted.mean(d[[v]], d$FACTOR_EXP_MUESTRA),
         tasa_no = tasa(d[[OBJ]][d[[v]] == 0], d$FACTOR_EXP_MUESTRA[d[[v]] == 0]),
         tasa_si = tasa(d[[OBJ]][d[[v]] == 1], d$FACTOR_EXP_MUESTRA[d[[v]] == 1]),
         v_cramer = cramers_v(table(d[[v]], d[[OBJ]]), adjust = FALSE)$Cramers_v)
}) |> mutate(diferencia = tasa_si - tasa_no) |> arrange(desc(abs(diferencia)))
write_csv(bin_tab, file.path(RES, "02_binarias.csv"))

# Correlaciones de Spearman entre predictores numéricos y binarios (easystats::correlation)
cor_tab <- correlation(d[d$CONJUNTO == "entrenamiento", c(num, bin)], method = "spearman", p_adjust = "none") |> as_tibble() |>
  select(var_1 = Parameter1, var_2 = Parameter2, rho) |> arrange(desc(abs(rho)))
write_csv(cor_tab, file.path(RES, "02_correlaciones_spearman.csv"))

g1 <- ggplot(por_anio, aes(factor(ANIO), tasa)) + geom_col(fill = VERDE, width = 0.6) +
  geom_text(aes(label = sprintf("%.1f %%", tasa)), vjust = -0.5, size = 3.6) +
  scale_y_continuous(limits = c(0, max(por_anio$tasa) * 1.15), labels = \(x) paste0(x, " %")) +
  labs(x = NULL, y = "Con crédito (ponderado)", title = "Acceso a crédito por año") + tema()
g2 <- ggplot(bin_tab |> slice_head(n = 10), aes(diferencia, reorder(etiqueta, diferencia))) +
  geom_col(fill = AZUL, width = 0.65) + geom_text(aes(label = sprintf("%+.1f", diferencia)), hjust = -0.15, size = 3.4) +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.15))) +
  labs(x = "Diferencia en la tasa de crédito (Sí − No), puntos porcentuales", y = NULL, title = "Características con mayor diferencia") + tema()
guardar(patchwork::wrap_plots(g1, g2, widths = c(1, 1.25)), "02_exploracion.png", 11, 4.2)

cat("Tasa ponderada global:", round(tasa(d$ACCESO_CREDITO, d$FACTOR_EXP_MUESTRA), 2), "%\n")
print(por_anio); print(por_region); print(head(bin_tab, 8)); print(head(cor_tab, 8))
