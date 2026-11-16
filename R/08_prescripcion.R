# 08 · Análisis prescriptivo: a quién priorizar y qué palancas mover (simulaciones con el modelo, conjunto de prueba).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages({ library(caret); library(xgboost) })
d <- cargar(); m <- readRDS(file.path(DATOS, "modelo_xgboost.rds"))
te <- d |> filter(CONJUNTO == "prueba"); vars <- m$vars; booster <- m$ajuste$finalModel$booster
prob <- function(dd) predict(booster, xgb.DMatrix(matriz(dd, vars)))
te$p <- prob(te); y <- te[[OBJ]]

# 1) Focalización: productores ordenados por probabilidad; cuántos con crédito se captan en cada tramo
foco <- te |> arrange(desc(p)) |> mutate(tramo = ceiling(10 * row_number() / n())) |> group_by(tramo) |>
  summarise(n = n(), con_credito = sum(.data[[OBJ]]), tasa = 100 * mean(.data[[OBJ]])) |>
  mutate(captado_acum = 100 * cumsum(con_credito) / sum(con_credito), elevacion = tasa / (100 * mean(y)))
write_csv(foco, file.path(RES, "08_focalizacion.csv"))

# 2) Escenarios: se cambia una palanca solo en quienes no la tienen y se recalcula la probabilidad media
palancas <- list("Asociatividad" = list(ASOCIADO = 1), "Venta a mercados regionales/Lima" = list(VENDE_LIMA_REGIONAL = 1),
                 "Riego en todos los cultivos" = list(PCT_CULTIVOS_RIEGO = 1), "Uso de fertilizantes" = list(USA_FERTILIZANTES = 1),
                 "Asociatividad + mercado" = list(ASOCIADO = 1, VENDE_LIMA_REGIONAL = 1),
                 "Las cuatro palancas" = list(ASOCIADO = 1, VENDE_LIMA_REGIONAL = 1, PCT_CULTIVOS_RIEGO = 1, USA_FERTILIZANTES = 1))
esc <- imap_dfr(palancas, function(cambio, nombre) {
  dd <- te; for (v in names(cambio)) dd[[v]] <- cambio[[v]]
  falta <- Reduce(`|`, lapply(names(cambio), function(v) te[[v]] < cambio[[v]]))
  p2 <- prob(dd)
  bind_rows(tibble(ambito = "Nacional", te = TRUE), tibble(ambito = as.character(levels(te$REGION)), te = NA)) |> distinct(ambito) |>
    mutate(escenario = nombre,
           sin_palanca = map_dbl(ambito, ~ 100 * mean(falta[if (.x == "Nacional") TRUE else te$REGION == .x])),
           base = map_dbl(ambito, ~ 100 * mean(te$p[if (.x == "Nacional") rep(TRUE, nrow(te)) else te$REGION == .x])),
           simulada = map_dbl(ambito, ~ 100 * mean(p2[if (.x == "Nacional") rep(TRUE, nrow(te)) else te$REGION == .x])),
           ganancia_pp = simulada - base,
           ganancia_beneficiarios_pp = map_dbl(ambito, ~ { i <- falta & (if (.x == "Nacional") TRUE else te$REGION == .x); 100 * mean(p2[i] - te$p[i]) }))
})
write_csv(esc, file.path(RES, "08_escenarios.csv"))

# 3) Demanda potencial: perfil parecido al de quienes tienen crédito (p >= umbral) pero sin crédito
te <- te |> mutate(grupo = case_when(p >= m$umbral & .data[[OBJ]] == 0 ~ "Potencial sin crédito", .data[[OBJ]] == 1 ~ "Con crédito", TRUE ~ "Resto sin crédito"))
perfil <- te |> group_by(grupo) |> summarise(n = n(), pct = 100 * n() / nrow(te), prob_media = 100 * mean(p), ha_cosechada_mediana = median(SUP_COSECHADA_HA),
            edad_media = mean(EDAD), asociado = 100 * mean(ASOCIADO), fertilizantes = 100 * mean(USA_FERTILIZANTES), vende_regional = 100 * mean(VENDE_LIMA_REGIONAL),
            riego = 100 * mean(PCT_CULTIVOS_RIEGO), costa = 100 * mean(REGION == "Costa"), sierra = 100 * mean(REGION == "Sierra"), selva = 100 * mean(REGION == "Selva"))
write_csv(perfil, file.path(RES, "08_perfil_grupos.csv"))
pot_dep <- te |> group_by(DEPARTAMENTO) |> summarise(n = n(), tasa_credito = 100 * mean(.data[[OBJ]]), potencial = 100 * mean(grupo == "Potencial sin crédito")) |> arrange(desc(potencial))
write_csv(pot_dep, file.path(RES, "08_potencial_departamento.csv"))

g1 <- ggplot(foco, aes(tramo, captado_acum)) + geom_abline(slope = 10, intercept = 0, linetype = 2, colour = GRIS) + geom_line(colour = VERDE, linewidth = 1) +
  geom_point(colour = VERDE, size = 2.4) + geom_text(aes(label = sprintf("%.0f", captado_acum)), vjust = -0.9, size = 3.1) +
  scale_x_continuous(breaks = 1:10, labels = paste0(seq(10, 100, 10), "%")) + scale_y_continuous(limits = c(0, 108)) +
  labs(x = "Productores atendidos (de mayor a menor probabilidad)", y = "% de productores con crédito captados", title = "Focalización") + tema()
g2 <- esc |> filter(ambito != "Nacional") |> mutate(escenario = factor(escenario, rev(names(palancas))), ambito = factor(ambito, c("Costa", "Sierra", "Selva"))) |>
  ggplot(aes(ganancia_pp, escenario, fill = ambito)) + geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_text(aes(label = sprintf("+%.1f", ganancia_pp)), position = position_dodge(0.8), hjust = -0.12, size = 2.9) +
  scale_fill_manual(values = c(Costa = NARANJA, Sierra = VERDE, Selva = AZUL), name = NULL) + scale_x_continuous(expand = expansion(mult = c(0.01, 0.14))) +
  labs(x = "Aumento de la tasa de crédito (puntos porcentuales)", y = NULL, title = "Escenarios por región") + tema() + theme(legend.position = "bottom")
guardar(patchwork::wrap_plots(g1, g2, widths = c(1, 1.15)), "08_prescripcion.png", 12.5, 4.8)
print(foco); print(esc, n = 40, width = 200); print(perfil, width = 250); print(head(pot_dep, 8)); print(tail(pot_dep, 4))
