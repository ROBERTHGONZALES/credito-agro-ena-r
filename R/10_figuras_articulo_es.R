# 10 · Figuras en español para la versión en español del artículo (mismo diseño que 09: una columna IEEE, 300 dpi, paleta Okabe-Ito).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
SAL <- file.path(BASE, "articulo", "figuras_es"); dir.create(SAL, recursive = TRUE, showWarnings = FALSE)
ES_VAR <- c(SUP_COSECHADA_HA = "Superficie cosechada (ha)", EDAD = "Edad", DEPARTAMENTO = "Departamento", TAM_HOGAR = "Tamaño del hogar",
            USA_FERTILIZANTES = "Usa fertilizantes", EDUCACION = "Nivel educativo", PCT_CULTIVOS_RIEGO = "% de cultivos con riego",
            USA_PLAGUICIDAS = "Usa plaguicidas", REGION = "Región natural", ASOCIADO = "Asociado",
            VENDE_LIMA_REGIONAL = "Vende a mercados regionales/Lima", ARRIENDA_TIERRA = "Arrienda tierra", SUP_TOTAL_HA = "Superficie total (ha)",
            PCT_CULTIVOS_VENDIDOS = "% de cultivos vendidos")
t8 <- theme_minimal(base_size = 8, base_family = "serif") + theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        axis.text = element_text(colour = "black"), legend.position = "bottom", legend.key.size = unit(8, "pt"), legend.margin = margin(0, 0, 0, 0), plot.margin = margin(3, 6, 3, 3))
g <- function(p, f, h) ggsave(file.path(SAL, f), p, width = 3.4, height = h, dpi = 300, bg = "white")
dec <- function(x, k) formatC(x, format = "f", digits = k, decimal.mark = ".")

imp <- read_csv(file.path(RES, "06_importancia_shap.csv"), show_col_types = FALSE) |> mutate(es = ES_VAR[variable])
stopifnot(!anyNA(imp$es))
g(ggplot(imp, aes(shap, reorder(es, shap))) + geom_col(fill = "#0072B2", width = 0.7) + geom_text(aes(label = dec(shap, 3)), hjust = -0.15, size = 2.3, family = "serif") +
    scale_x_continuous(expand = expansion(mult = c(0.01, 0.2))) + labs(x = "SHAP absoluto medio (log-odds)", y = NULL) + t8, "fig1_shap.png", 2.7)

foco <- read_csv(file.path(RES, "08_focalizacion.csv"), show_col_types = FALSE)
g(ggplot(bind_rows(tibble(tramo = 0, captado_acum = 0), foco), aes(10 * tramo, captado_acum)) + geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey50") +
    geom_line(linewidth = 0.6, colour = "#0072B2") + geom_point(size = 1.2, colour = "#0072B2") + geom_text(data = foco, aes(label = dec(captado_acum, 0)), vjust = -0.9, size = 2.3, family = "serif") +
    scale_x_continuous(breaks = seq(0, 100, 20)) + scale_y_continuous(limits = c(0, 109), breaks = seq(0, 100, 25)) +
    labs(x = "Productores atendidos, ordenados por probabilidad (%)", y = "Productores con crédito captados (%)") + t8 + theme(panel.grid.major.y = element_line()), "fig2_gain.png", 2.4)

esc <- read_csv(file.path(RES, "08_escenarios.csv"), show_col_types = FALSE) |> filter(ambito != "Nacional")
ESC <- c("Asociatividad" = "Asociatividad", "Venta a mercados regionales/Lima" = "Venta a mercados regionales/Lima", "Riego en todos los cultivos" = "Riego en todos los cultivos",
         "Uso de fertilizantes" = "Uso de fertilizantes", "Asociatividad + mercado" = "Asociatividad + mercado", "Las cuatro palancas" = "Las cuatro acciones")
esc <- esc |> mutate(es = factor(ESC[escenario], rev(unname(ESC))), reg = factor(ambito, c("Selva", "Sierra", "Costa")))
stopifnot(!anyNA(esc$es), !anyNA(esc$reg))
g(ggplot(esc, aes(ganancia_pp, es, fill = reg)) + geom_col(position = position_dodge(0.8), width = 0.75) +
    geom_text(aes(label = paste0("+", dec(ganancia_pp, 1))), position = position_dodge(0.8), hjust = -0.12, size = 2.1, family = "serif") +
    scale_fill_manual(values = c(Costa = "#D55E00", Sierra = "#004D40", Selva = "#9AD0F5"), name = NULL, breaks = c("Costa", "Sierra", "Selva")) +
    scale_x_continuous(expand = expansion(mult = c(0.01, 0.14))) + labs(x = "Aumento de la tasa de acceso (pp)", y = NULL) + t8, "fig3_scenarios.png", 3.3)
cat("ok\n")
