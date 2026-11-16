# 09 · Figuras en inglés para el artículo (ancho de una columna IEEE, 300 dpi; paleta Okabe-Ito, apta para daltónicos), a partir de las tablas de resultados.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
SAL <- file.path(BASE, "articulo", "figuras"); dir.create(SAL, recursive = TRUE, showWarnings = FALSE)
EN <- c(SUP_COSECHADA_HA = "Harvested area (ha)", EDAD = "Age", DEPARTAMENTO = "Department", TAM_HOGAR = "Household size",
        USA_FERTILIZANTES = "Uses fertilizers", EDUCACION = "Education level", PCT_CULTIVOS_RIEGO = "Share of irrigated crops",
        USA_PLAGUICIDAS = "Uses pesticides", REGION = "Natural region", ASOCIADO = "Association member",
        VENDE_LIMA_REGIONAL = "Sells to regional/Lima markets", ARRIENDA_TIERRA = "Rents land", SUP_TOTAL_HA = "Total area (ha)",
        PCT_CULTIVOS_VENDIDOS = "Share of crops sold")
t8 <- theme_minimal(base_size = 8, base_family = "serif") + theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        axis.text = element_text(colour = "black"), legend.position = "bottom", legend.key.size = unit(8, "pt"), legend.margin = margin(0, 0, 0, 0), plot.margin = margin(3, 6, 3, 3))
g <- function(p, f, h) ggsave(file.path(SAL, f), p, width = 3.4, height = h, dpi = 300, bg = "white")

imp <- read_csv(file.path(RES, "06_importancia_shap.csv"), show_col_types = FALSE) |> mutate(en = EN[variable])
g(ggplot(imp, aes(shap, reorder(en, shap))) + geom_col(fill = "#0072B2", width = 0.7) + geom_text(aes(label = sprintf("%.3f", shap)), hjust = -0.15, size = 2.3, family = "serif") +
    scale_x_continuous(expand = expansion(mult = c(0.01, 0.16))) + labs(x = "Mean absolute SHAP value (log-odds)", y = NULL) + t8, "fig1_shap.png", 2.7)

foco <- read_csv(file.path(RES, "08_focalizacion.csv"), show_col_types = FALSE)
g(ggplot(bind_rows(tibble(tramo = 0, captado_acum = 0), foco), aes(10 * tramo, captado_acum)) + geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
    geom_line(linewidth = 0.6, colour = "#0072B2") + geom_point(size = 1.2, colour = "#0072B2") + geom_text(data = foco, aes(label = sprintf("%.0f", captado_acum)), vjust = -0.9, size = 2.3, family = "serif") +
    scale_x_continuous(breaks = seq(0, 100, 20)) + scale_y_continuous(limits = c(0, 109), breaks = seq(0, 100, 25)) +
    labs(x = "Producers targeted, ranked by predicted probability (%)", y = "Credit holders captured (%)") + t8 + theme(panel.grid.major.y = element_line()), "fig2_gain.png", 2.4)

esc <- read_csv(file.path(RES, "08_escenarios.csv"), show_col_types = FALSE) |> filter(ambito != "Nacional")
ES <- c("Asociatividad" = "Association membership", "Venta a mercados regionales/Lima" = "Regional/Lima market sales", "Riego en todos los cultivos" = "Irrigation on all crops",
        "Uso de fertilizantes" = "Fertilizer use", "Asociatividad + mercado" = "Association + market", "Las cuatro palancas" = "All four levers")
esc <- esc |> mutate(en = factor(ES[escenario], rev(unname(ES))), reg = factor(c(Costa = "Coast", Sierra = "Highlands", Selva = "Rainforest")[ambito], c("Rainforest", "Highlands", "Coast")))
g(ggplot(esc, aes(ganancia_pp, en, fill = reg)) + geom_col(position = position_dodge(0.8), width = 0.75) +
    geom_text(aes(label = sprintf("+%.1f", ganancia_pp)), position = position_dodge(0.8), hjust = -0.12, size = 2.1, family = "serif") +
    scale_fill_manual(values = c(Coast = "#D55E00", Highlands = "#004D40", Rainforest = "#9AD0F5"), name = NULL, breaks = c("Coast", "Highlands", "Rainforest")) +
    scale_x_continuous(expand = expansion(mult = c(0.01, 0.14))) + labs(x = "Increase in access rate (percentage points)", y = NULL) + t8, "fig3_scenarios.png", 3.3)
cat("ok\n")
