# Dashboard · Acceso al crédito agrario en el Perú (ENA 2016–2025)
# Ejecutar desde la carpeta AGRO:  Rscript -e "shiny::runApp('R/dashboard', port = 8052)"
# o en Positron: abrir este archivo y pulsar "Run App".
# Lee solo tablas agregadas y las predicciones del conjunto de prueba (R/dashboard/datos, generadas por R/15_exportar_csv.R).
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(bsicons); library(plotly); library(DT); library(dplyr); library(readr); library(tidyr)
})
leer <- function(f) read_csv(file.path("datos", f), show_col_types = FALSE)

# ---- Datos ---------------------------------------------------------------------------------------
acceso    <- leer("acceso_anio.csv")
dep_anio  <- leer("departamento_anio.csv") |> filter(!is.na(DEPARTAMENTO), DEPARTAMENTO != "Callao")
prest     <- leer("14_prestamistas_anio.csv")
perfil    <- leer("14_prestamistas_perfil.csv")
crisis    <- leer("14_prestamistas_crisis_agrobanco.csv")
dep_brec  <- leer("13_departamentos_datos_completos.csv")
bench     <- leer("13_benchmarks.csv")
esc_ic    <- leer("11_escenarios_ic.csv")
esc_pond  <- leer("13_escenarios_ponderados.csv")
asig      <- leer("13_asignacion_cruzada.csv")
foco      <- leer("08_focalizacion.csv")
shap      <- leer("06_importancia_shap.csv")
efectos   <- leer("06_efectos_pp.csv")
valid     <- leer("11_validacion_temporal_espacial.csv")
pred      <- leer("prueba_predicciones.csv")

TIPOS <- c(pub = "Público nacional", cmac = "Caja municipal", priv = "Privado regulado", coop = "Cooperativa u ONG", inf = "Informal")
COL_T <- c("Público nacional" = "#0072B2", "Caja municipal" = "#E69F00", "Privado regulado" = "#D55E00", "Cooperativa u ONG" = "#009E73", "Informal" = "#999999")
COL_R <- c(Nacional = "#1F2937", Costa = "#D55E00", Sierra = "#004D40", Selva = "#56B4E9")
AZUL <- "#0072B2"; GRIS <- "#6B7280"
ESC <- c("Asociatividad" = "Asociatividad", "Venta a mercados regionales/Lima" = "Venta a mercados", "Riego en todos los cultivos" = "Riego en todos los cultivos",
         "Uso de fertilizantes" = "Uso de fertilizantes", "Asociatividad + mercado" = "Asociatividad + mercado", "Las cuatro palancas" = "Las cuatro acciones")
DEPTOS <- sort(unique(dep_anio$DEPARTAMENTO))
ANIOS <- sort(unique(acceso$ANIO))
`%||%` <- function(a, b) if (is.null(a)) b else a
pct <- function(x, k = 1) paste0(formatC(x, format = "f", digits = k), " %")
miles <- function(x) format(round(x), big.mark = ",")

lay <- function(p, ytitle = NULL, xtitle = NULL, ...) p |>
  layout(yaxis = list(title = ytitle %||% "", gridcolor = "#E5E7EB", zeroline = FALSE), xaxis = list(title = xtitle %||% "", gridcolor = "#F3F4F6"),
         legend = list(orientation = "h", y = -0.18), margin = list(l = 10, r = 10, t = 10, b = 10), font = list(size = 13),
         hoverlabel = list(bgcolor = "#111827", font = list(color = "white", size = 13)), ...) |>
  config(displayModeBar = FALSE)

nota <- function(...) p(class = "text-muted small mb-0", ...)

tema <- bs_theme(version = 5, primary = AZUL, "navbar-bg" = "#0B3D5C", base_font = font_google("Inter"), heading_font = font_google("Inter"),
                 bg = "#FFFFFF", fg = "#111827")

# ---- Interfaz --------------------------------------------------------------------------------------
ui <- page_navbar(
  title = "Crédito agrario en el Perú · ENA 2016–2025", theme = tema, fillable = FALSE,
  header = tags$style(HTML(".bslib-value-box .value-box-value{font-size:1.9rem} .card-header{font-weight:600} .small{font-size:.85rem}")),

  nav_panel("Panorama", icon = bs_icon("speedometer2"),
    layout_column_wrap(width = 1/4, fill = FALSE,
      value_box("Acceso al crédito (2025)", uiOutput("vb_acceso"), showcase = bs_icon("cash-coin"), theme = "primary",
                p("productores que solicitaron y obtuvieron crédito, ponderado")),
      value_box("Solicitaron crédito", "13.0 %", showcase = bs_icon("pencil-square"), theme = "light", p("de todos los productores (2016–2025)")),
      value_box("Aprobados", "91.9 %", showcase = bs_icon("check2-circle"), theme = "light", p("de los que solicitaron: la barrera está antes de pedir")),
      value_box("Prestamista público (2025)", uiOutput("vb_publico"), showcase = bs_icon("bank"), theme = "light", p("de los prestatarios usó Agrobanco o un programa del Estado"))),
    layout_columns(col_widths = c(8, 4),
      card(card_header("¿Cuántos productores tienen crédito y cuántos lo piden?"),
           radioButtons("pan_reg", NULL, c("Nacional", "Costa", "Sierra", "Selva"), inline = TRUE),
           plotlyOutput("g_acceso", height = 330),
           nota("Línea sólida: solicitaron y obtuvieron. Discontinua: solicitaron. Ponderado con los factores de expansión. Faltan 2018 (sin superficie en hectáreas), 2020 (sin encuesta) y 2021 (sin módulo de crédito).")),
      card(card_header("Lo que hay que saber"),
           tags$ul(class = "mb-0",
             tags$li(strong("Solo 1 de cada 10"), " pequeños y medianos productores obtiene crédito."),
             tags$li("Casi todos los que piden crédito lo reciben: ", strong("el problema es que pocos lo piden.")),
             tags$li("La ", strong("costa"), " duplica el acceso de la ", strong("sierra"), "."),
             tags$li("El modelo ordena bien a los productores (AUC 0.80): el 20 % con mayor probabilidad reúne al ", strong("54 %"), " de quienes tienen crédito."),
             tags$li("Estar ", strong("asociado"), " es lo que más se relaciona con tener crédito (odds ×2)."))))),

  nav_panel("¿Quién presta?", icon = bs_icon("building"),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Prestatarios por tipo de prestamista, por cada 100 productores"),
           plotlyOutput("g_tipos", height = 340),
           nota("Público: Agrobanco y programas del Estado. Privado regulado: bancos, cajas rurales y financieras. Un productor puede usar más de un tipo.")),
      card(card_header("Cuando Agrobanco cayó, nadie lo reemplazó"),
           plotlyOutput("g_crisis", height = 340),
           nota("Productores cuyo perfil se parece al de los clientes de Agrobanco (cuartil superior) frente al resto. Entre 2017 y 2019 su crédito de Agrobanco cayó de 5.4 % a 1.4 % y el de otros prestamistas no subió."))),
    layout_columns(col_widths = c(5, 7),
      card(card_header("Mezcla de prestamistas en un departamento"),
           selectInput("dep_mix", NULL, DEPTOS, selected = "Puno"),
           plotlyOutput("g_mix_dep", height = 300),
           nota("Prestatarios de cada tipo por cada 100 productores del departamento, por año.")),
      card(card_header("¿A quién atiende cada prestamista?"), DTOutput("t_perfil"),
           nota("Clientes con un solo tipo de prestamista, ponderado. Probabilidad predicha: probabilidad de tener crédito según el modelo.")))),

  nav_panel("Mi departamento", icon = bs_icon("geo-alt"),
    layout_sidebar(
      sidebar = sidebar(width = 260, selectInput("dep", "Departamento", DEPTOS, selected = "Puno"),
                        uiOutput("dep_texto")),
      layout_column_wrap(width = 1/3, fill = FALSE,
        value_box("Acceso al crédito (todas las rondas)", uiOutput("vb_dep_acceso"), showcase = bs_icon("cash-stack"), theme = "primary"),
        value_box("Brecha de propensión", uiOutput("vb_dep_brecha"), showcase = bs_icon("people"), theme = "light",
                  p("productores sin crédito con perfil de tener crédito")),
        value_box("Puesto entre 24 departamentos", uiOutput("vb_dep_puesto"), showcase = bs_icon("trophy"), theme = "light", p("según tasa de crédito"))),
      layout_columns(col_widths = c(6, 6),
        card(card_header("Acceso por año frente al promedio nacional"), plotlyOutput("g_dep_anio", height = 300)),
        card(card_header("Ranking de departamentos"), radioButtons("rank_var", NULL, c("Tasa de crédito" = "tasa_credito", "Brecha de propensión" = "brecha"), inline = TRUE),
             plotlyOutput("g_ranking", height = 300)))) ),

  nav_panel("Simulador de focalización", icon = bs_icon("bullseye"),
    layout_sidebar(
      sidebar = sidebar(width = 300,
        sliderInput("cobertura", "Si un programa atiende al … de productores con mayor probabilidad", min = 5, max = 50, value = 20, step = 5, post = " %"),
        sliderInput("umbral", "Umbral de probabilidad para la brecha", min = 0.05, max = 0.50, value = 0.175, step = 0.025),
        radioButtons("sim_reg", "Región", c("Nacional", "Costa", "Sierra", "Selva")),
        nota("Calculado con los 9,969 productores de prueba, que el modelo no vio al entrenar.")),
      layout_column_wrap(width = 1/3, fill = FALSE,
        value_box("Captaría a", uiOutput("vb_captados"), showcase = bs_icon("funnel"), theme = "primary", p("de quienes tienen crédito")),
        value_box("Eficiencia frente al azar", uiOutput("vb_lift"), showcase = bs_icon("graph-up-arrow"), theme = "light"),
        value_box("Brecha con este umbral", uiOutput("vb_brecha"), showcase = bs_icon("person-x"), theme = "light", uiOutput("vb_brecha_sub"))),
      card(card_header("Curva de ganancia: % de productores con crédito captados según la cobertura"), plotlyOutput("g_ganancia", height = 330),
           nota("La línea discontinua es elegir al azar. El punto marca la cobertura elegida.")))),

  nav_panel("Escenarios", icon = bs_icon("sliders"),
    layout_columns(col_widths = c(7, 5),
      card(card_header("¿Qué pasaría con la tasa de acceso si los productores que no tienen una condición la tuvieran?"),
           radioButtons("esc_reg", NULL, c("Nacional", "Costa", "Sierra", "Selva"), inline = TRUE),
           plotlyOutput("g_escenarios", height = 360),
           nota(strong("Ojo: "), "son simulaciones del modelo, no efectos causales. Asociarse puede ser causa o consecuencia del crédito. Barras: intervalo bootstrap del 95 %.")),
      card(card_header("Programa con presupuesto: ¿a quién asociar?"), DTOutput("t_asig"),
           nota("Nuevos accesos esperados al promover la asociatividad entre no asociados sin crédito (conjunto de prueba). Un modelo elige y otro independiente evalúa. Elegir por probabilidad funciona igual que por ganancia y ~1.6 veces mejor que al azar."),
           hr(), DTOutput("t_pond"), nota("Tasa nacional simulada sin ponderar y ponderada con los factores de expansión.")))),

  nav_panel("El modelo", icon = bs_icon("cpu"),
    layout_columns(col_widths = c(6, 6),
      card(card_header("¿Qué variables pesan más? (importancia SHAP)"), plotlyOutput("g_shap", height = 380)),
      card(card_header("Efecto en la probabilidad de tener crédito (puntos porcentuales)"), plotlyOutput("g_efectos", height = 380),
           nota("Cambio medio de la probabilidad predicha al pasar de No a Sí, o del percentil 25 al 75."))),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Cinco modelos rinden casi igual (AUC-ROC con IC 95 %)"), plotlyOutput("g_bench", height = 300),
           nota("Lo que limita la precisión es la información de la encuesta, no el algoritmo.")),
      card(card_header("Validación fuera de muestra"), DTOutput("t_valid")))),

  nav_spacer(),
  nav_item(tags$span(class = "text-white-50 small", "Fuente: INEI · ENA. Elaboración: Gonzales y Gómez (UNA Puno)"))
)

# ---- Servidor ----------------------------------------------------------------------------------------
server <- function(input, output, session) {
  output$vb_acceso <- renderUI(pct(acceso$acceso[acceso$REGION == "Nacional" & acceso$ANIO == max(ANIOS)]))
  output$vb_publico <- renderUI(pct(prest$part_pub[prest$ANIO == max(prest$ANIO)], 0))

  output$g_acceso <- renderPlotly({
    reg <- input$pan_reg; a <- acceso |> filter(REGION %in% unique(c("Nacional", reg)))
    p <- plot_ly()
    for (r in unique(a$REGION)) {
      ar <- a |> filter(REGION == r)
      p <- p |> add_trace(data = ar, x = ~factor(ANIO), y = ~acceso, type = "scatter", mode = "lines+markers", name = paste(r, "· obtuvo"),
                          line = list(color = COL_R[[r]], width = 3), marker = list(color = COL_R[[r]], size = 8),
                          hovertemplate = paste0(r, " %{x}: %{y:.1f} % obtuvo<extra></extra>")) |>
        add_trace(data = ar, x = ~factor(ANIO), y = ~solicitud, type = "scatter", mode = "lines", name = paste(r, "· solicitó"),
                  line = list(color = COL_R[[r]], dash = "dash", width = 2), hovertemplate = paste0(r, " %{x}: %{y:.1f} % solicitó<extra></extra>"))
    }
    lay(p, "% de productores")
  })

  output$g_tipos <- renderPlotly({
    l <- prest |> select(ANIO, starts_with("por100_")) |> pivot_longer(-ANIO) |> mutate(tipo = TIPOS[sub("por100_", "", name)])
    plot_ly(l, x = ~factor(ANIO), y = ~value, color = ~tipo, colors = COL_T, type = "scatter", mode = "lines+markers",
            line = list(width = 3), marker = list(size = 8), hovertemplate = "%{x} · %{y:.1f} por cada 100<extra>%{fullData.name}</extra>") |>
      lay("Por cada 100 productores")
  })
  output$g_crisis <- renderPlotly({
    cr <- crisis |> mutate(g = if_else(grepl("Agrobanco", grupo), "Perfil tipo Agrobanco", "Resto"), anio = ANIO)
    cols <- c("Perfil tipo Agrobanco" = AZUL, "Resto" = GRIS); p <- plot_ly()
    for (gg in names(cols)) {
      cg <- cr |> filter(g == gg)
      p <- p |> add_trace(x = cg$anio, y = cg$acceso, type = "scatter", mode = "lines+markers", name = paste(gg, "· cualquier prestamista"),
                          line = list(color = cols[[gg]], width = 3), marker = list(color = cols[[gg]], size = 8),
                          hovertemplate = paste0(gg, " %{x}: %{y:.1f} % con crédito<extra></extra>")) |>
        add_trace(x = cg$anio, y = cg$pct_agrobanco, type = "scatter", mode = "lines", name = paste(gg, "· Agrobanco"),
                  line = list(color = cols[[gg]], dash = "dot", width = 2), hovertemplate = paste0(gg, " %{x}: %{y:.1f} % de Agrobanco<extra></extra>"))
    }
    p |> lay("% de productores")
  })
  output$g_mix_dep <- renderPlotly({
    dd <- dep_anio |> filter(DEPARTAMENTO == input$dep_mix) |> select(ANIO, tipo_publico:tipo_informal) |> pivot_longer(-ANIO) |>
      mutate(tipo = recode(name, tipo_publico = TIPOS[["pub"]], tipo_caja_municipal = TIPOS[["cmac"]], tipo_privado_regulado = TIPOS[["priv"]],
                           tipo_cooperativa_ong = TIPOS[["coop"]], tipo_informal = TIPOS[["inf"]]))
    plot_ly(dd, x = ~factor(ANIO), y = ~value, color = ~tipo, colors = COL_T, type = "bar", hovertemplate = "%{x}: %{y:.1f} por cada 100<extra>%{fullData.name}</extra>") |>
      lay("Por cada 100 productores", barmode = "stack")
  })
  output$t_perfil <- renderDT({
    t <- perfil |> transmute(Prestamista = tipo, `Clientes` = miles(clientes), `Prob. predicha` = pct(prob_predicha), `Ha cosechadas` = round(ha_cosechada_mediana, 1),
                             Asociados = pct(asociado, 0), Sierra = pct(sierra, 0), Selva = pct(selva, 0), `Uso en insumos` = pct(uso_insumos_agricolas, 0))
    datatable(t, rownames = FALSE, options = list(dom = "t", ordering = FALSE), class = "compact stripe")
  })

  # Mi departamento
  dsel <- reactive(dep_brec |> filter(DEPARTAMENTO == input$dep))
  output$vb_dep_acceso <- renderUI(pct(dsel()$tasa_credito))
  output$vb_dep_brecha <- renderUI(tagList(pct(dsel()$brecha), tags$div(class = "small", sprintf("IC 95 %%: %.0f–%.0f %%", dsel()$inf, dsel()$sup))))
  output$vb_dep_puesto <- renderUI(paste0(rank(-dep_brec$tasa_credito)[dep_brec$DEPARTAMENTO == input$dep], "º"))
  output$dep_texto <- renderUI({
    d <- dep_anio |> filter(DEPARTAMENTO == input$dep, ANIO == max(ANIO))
    mix <- c("Público nacional" = d$tipo_publico, "Caja municipal" = d$tipo_caja_municipal, "Privado regulado" = d$tipo_privado_regulado,
             "Cooperativa u ONG" = d$tipo_cooperativa_ong, "Informal" = d$tipo_informal)
    tagList(hr(), p(strong(input$dep), " · región ", d$REGION), p(sprintf("En %d, %.1f de cada 100 productores obtuvo crédito; el prestamista más usado fue: %s.",
                                                                          d$ANIO, d$acceso, names(which.max(mix)))),
            nota("Datos de los 196,566 productores depurados. La brecha es mayor donde el crédito ya es frecuente: indica dónde promover solicitudes, no regiones olvidadas."))
  })
  output$g_dep_anio <- renderPlotly({
    d <- dep_anio |> filter(DEPARTAMENTO == input$dep); n <- acceso |> filter(REGION == "Nacional")
    plot_ly() |>
      add_trace(data = d, x = ~factor(ANIO), y = ~acceso, type = "bar", name = input$dep, marker = list(color = AZUL), hovertemplate = "%{x}: %{y:.1f} %<extra></extra>") |>
      add_trace(data = n, x = ~factor(ANIO), y = ~acceso, type = "scatter", mode = "lines+markers", name = "Perú", line = list(color = "#1F2937", width = 3),
                hovertemplate = "Perú %{x}: %{y:.1f} %<extra></extra>") |> lay("% con crédito")
  })
  output$g_ranking <- renderPlotly({
    v <- input$rank_var
    r <- dep_brec |> mutate(val = .data[[v]], sel = DEPARTAMENTO == input$dep) |> arrange(val) |> mutate(DEPARTAMENTO = factor(DEPARTAMENTO, DEPARTAMENTO))
    plot_ly(r, x = ~val, y = ~DEPARTAMENTO, type = "bar", orientation = "h", marker = list(color = ifelse(r$sel, "#D55E00", "#9CA3AF")),
            hovertemplate = "%{y}: %{x:.1f} %<extra></extra>") |> lay(NULL, "%")
  })

  # Simulador
  psel <- reactive(if (input$sim_reg == "Nacional") pred else pred |> filter(REGION == input$sim_reg))
  sim <- reactive({
    d <- psel() |> arrange(desc(p)); k <- ceiling(nrow(d) * input$cobertura / 100)
    capt <- sum(d$y[seq_len(k)]) / sum(d$y)
    br <- d$p >= input$umbral & d$y == 0
    list(capt = capt, lift = capt / (input$cobertura / 100), brecha = mean(br), sol = mean(d$solicito[br], na.rm = TRUE),
         prec = mean(d$y[d$p >= input$umbral]), d = d)
  })
  output$vb_captados <- renderUI(pct(100 * sim()$capt, 0))
  output$vb_lift <- renderUI(paste0(formatC(sim()$lift, format = "f", digits = 1), " veces"))
  output$vb_brecha <- renderUI(pct(100 * sim()$brecha))
  output$vb_brecha_sub <- renderUI(p(sprintf("de los productores; solo el %.1f %% de ellos solicitó crédito. Precisión del umbral: %.0f %%.", 100 * sim()$sol, 100 * sim()$prec)))
  output$g_ganancia <- renderPlotly({
    d <- sim()$d; n <- nrow(d); cs <- cumsum(d$y) / sum(d$y)
    idx <- unique(c(1, round(seq(0.01, 1, by = 0.01) * n)))
    cur <- tibble(cob = 100 * idx / n, capt = 100 * cs[idx])
    pt <- tibble(cob = input$cobertura, capt = 100 * sim()$capt)
    plot_ly(cur, x = ~cob, y = ~capt, type = "scatter", mode = "lines", name = "Modelo", line = list(color = AZUL, width = 3),
            hovertemplate = "Atender %{x:.0f} % → capta %{y:.0f} %<extra></extra>") |>
      add_trace(x = c(0, 100), y = c(0, 100), mode = "lines", name = "Azar", line = list(color = GRIS, dash = "dash"), hoverinfo = "skip") |>
      add_trace(data = pt, x = ~cob, y = ~capt, mode = "markers", name = "Elegido", marker = list(color = "#D55E00", size = 14)) |>
      lay("% de productores con crédito captados", "% de productores atendidos")
  })

  # Escenarios
  output$g_escenarios <- renderPlotly({
    e <- esc_ic |> filter(ambito == input$esc_reg) |> mutate(esc = factor(ESC[escenario], rev(unname(ESC))))
    base <- e$base[1]
    plot_ly(e, x = ~simulada, y = ~esc, type = "bar", orientation = "h", marker = list(color = AZUL),
            error_x = list(type = "data", symmetric = FALSE, array = ~sim_sup - simulada, arrayminus = ~simulada - sim_inf, color = "#111827"),
            hovertemplate = "%{y}: %{x:.1f} %<extra></extra>") |>
      lay(NULL, "Tasa de acceso simulada (%)", showlegend = FALSE,
          shapes = list(list(type = "line", x0 = base, x1 = base, yref = "paper", y0 = 0, y1 = 1, line = list(color = "#D55E00", dash = "dash", width = 2))),
          annotations = list(list(x = base, y = 1, yref = "paper", text = sprintf("Hoy: %.1f %%", base), showarrow = FALSE, xanchor = "left",
                                  yanchor = "top", xshift = 4, font = list(color = "#D55E00", size = 13))))
  })
  output$t_asig <- renderDT({
    a <- asig |> mutate(regla = recode(regla, ganancia = "Por ganancia simulada", probabilidad = "Por mayor probabilidad", azar = "Al azar"),
                        v = sprintf("%.0f (%.0f–%.0f)", cruzado, inf, sup)) |> select(K, regla, v) |> pivot_wider(names_from = regla, values_from = v) |>
      rename(`Productores atendidos` = K)
    datatable(a, rownames = FALSE, options = list(dom = "t", ordering = FALSE), class = "compact stripe")
  })
  output$t_pond <- renderDT({
    t <- esc_pond |> transmute(Escenario = recode(escenario, "Base" = "Situación actual", !!!as.list(ESC)), `Sin ponderar` = pct(sin_ponderar), Ponderada = pct(ponderado))
    datatable(t, rownames = FALSE, options = list(dom = "t", ordering = FALSE), class = "compact stripe")
  })

  # Modelo
  output$g_shap <- renderPlotly({
    s <- shap |> arrange(shap) |> mutate(etiqueta = factor(etiqueta, etiqueta))
    plot_ly(s, x = ~shap, y = ~etiqueta, type = "bar", orientation = "h", marker = list(color = AZUL), hovertemplate = "%{y}: %{x:.3f}<extra></extra>") |>
      lay(NULL, "SHAP absoluto medio (log-odds)")
  })
  output$g_efectos <- renderPlotly({
    e <- efectos |> arrange(efecto_pp) |> mutate(etiqueta = factor(etiqueta, etiqueta))
    plot_ly(e, x = ~efecto_pp, y = ~etiqueta, type = "bar", orientation = "h", text = ~tipo, textposition = "none",
            marker = list(color = ifelse(e$efecto_pp >= 0, AZUL, "#D55E00")), hovertemplate = "%{y} (%{text}): %{x:+.1f} pp<extra></extra>") |>
      lay(NULL, "Puntos porcentuales")
  })
  output$g_bench <- renderPlotly({
    b <- bench |> mutate(modelo = recode(modelo, "Logística penalizada (elastic net)" = "Logística elastic net")) |> arrange(auc_roc) |>
      mutate(modelo = factor(modelo, modelo))
    plot_ly(b, x = ~auc_roc, y = ~modelo, type = "scatter", mode = "markers", marker = list(color = AZUL, size = 12),
            error_x = list(type = "data", symmetric = FALSE, array = ~auc_roc_sup - auc_roc, arrayminus = ~auc_roc - auc_roc_inf, color = AZUL),
            hovertemplate = "%{y}: %{x:.3f}<extra></extra>") |> lay(NULL, "AUC-ROC en el conjunto de prueba")
  })
  output$t_valid <- renderDT({
    v <- bind_rows(tibble(Prueba = "Conjunto de prueba (9,969 productores)", `AUC-ROC` = 0.798, `AUC-PR` = 0.367),
                   valid |> transmute(Prueba = recode(validacion, "Temporal: 2016-2023 -> 2024-2025" = "Entrenar 2016–2023, probar 2024–2025",
                                                      "Espacial: sin Costa" = "Sin la costa (probar en la costa)", "Espacial: sin Sierra" = "Sin la sierra",
                                                      "Espacial: sin Selva" = "Sin la selva"), `AUC-ROC` = round(auc_roc, 3), `AUC-PR` = round(auc_pr, 3)),
                   tibble(Prueba = "Todos los datos depurados (196,566)", `AUC-ROC` = 0.801, `AUC-PR` = 0.357))
    datatable(v, rownames = FALSE, options = list(dom = "t", ordering = FALSE), class = "compact stripe")
  })
}

shinyApp(ui, server)
