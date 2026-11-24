# Dashboard · Acceso al crédito agrario en el Perú (ENA 2016–2025)
# Local:   Rscript -e "shiny::runApp('R/dashboard', port = 8052)"   o "Run App" en Positron.
# Web:     versión Shinylive (corre en el navegador) publicada en GitHub Pages; se exporta con R/17_publicar_dashboard.R.
# Lee solo tablas agregadas y las predicciones del conjunto de prueba (R/dashboard/datos, generadas por los scripts 15 y 16).
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(bsicons); library(plotly); library(DT); library(dplyr); library(tidyr)
})
leer <- function(f) utils::read.csv(file.path("datos", f), check.names = FALSE, fileEncoding = "UTF-8", stringsAsFactors = FALSE)

# ---- Datos -----------------------------------------------------------------------------------------
acceso   <- leer("acceso_anio.csv")
dep_anio <- leer("departamento_anio.csv") |> filter(DEPARTAMENTO != "", DEPARTAMENTO != "Callao")
perfil   <- leer("dep_perfil.csv")
dep_esc  <- leer("dep_escenarios.csv")
dep_shap <- leer("dep_shap.csv")
dep_pres <- leer("dep_prestamistas.csv")
dep_brec <- leer("13_departamentos_datos_completos.csv")
prest    <- leer("14_prestamistas_anio.csv")
pperfil  <- leer("14_prestamistas_perfil.csv")
crisis   <- leer("14_prestamistas_crisis_agrobanco.csv")
bench    <- leer("13_benchmarks.csv")
esc_ic   <- leer("11_escenarios_ic.csv")
esc_pond <- leer("13_escenarios_ponderados.csv")
asig     <- leer("13_asignacion_cruzada.csv")
shap     <- leer("06_importancia_shap.csv")
efectos  <- leer("06_efectos_pp.csv")
valid    <- leer("11_validacion_temporal_espacial.csv")
pred     <- leer("prueba_predicciones.csv")

PERU   <- perfil |> filter(DEPARTAMENTO == "Perú") |> mutate(brecha = with(dep_brec, sum(brecha * n) / sum(n)))
DEPS   <- perfil |> filter(DEPARTAMENTO != "Perú") |>
  left_join(dep_brec |> select(DEPARTAMENTO, brecha, brecha_inf = inf, brecha_sup = sup), by = "DEPARTAMENTO") |>
  left_join(dep_pres |> select(DEPARTAMENTO, part_pub, part_cmac, part_priv, part_coop, part_inf), by = "DEPARTAMENTO") |>
  left_join(dep_shap |> select(DEPARTAMENTO = departamento, shap), by = "DEPARTAMENTO")
DEPTOS <- sort(DEPS$DEPARTAMENTO)
ANIOS  <- sort(unique(acceso$ANIO))

TIPOS <- c(pub = "Público nacional", cmac = "Caja municipal", priv = "Privado regulado", coop = "Cooperativa u ONG", inf = "Informal")
COL_T <- c("Público nacional" = "#0072B2", "Caja municipal" = "#E69F00", "Privado regulado" = "#D55E00", "Cooperativa u ONG" = "#009E73", "Informal" = "#999999")
COL_R <- c(Nacional = "#1F2937", Costa = "#D55E00", Sierra = "#004D40", Selva = "#56B4E9")
COL_CMP <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7")
AZUL <- "#0072B2"; NARANJA <- "#D55E00"; GRIS <- "#6B7280"
ESC_N <- c("Asociatividad", "Venta a mercados", "Riego en todos los cultivos", "Uso de fertilizantes", "Asociatividad + mercado", "Las cuatro acciones")

INDIC <- c("Acceso al crédito (%)" = "acceso", "Solicitaron crédito (%)" = "solicitud", "Brecha de propensión (%)" = "brecha",
           "Asociados (%)" = "asociado", "Usan fertilizantes (%)" = "fertilizantes", "Cultivos con riego (%)" = "riego",
           "Venden a mercados regionales (%)" = "vende_regional", "Recibieron capacitación (%)" = "capacitacion",
           "Prestatarios del público (%)" = "part_pub", "Prestatarios de cajas municipales (%)" = "part_cmac",
           "Prestatarios del privado regulado (%)" = "part_priv", "Prestatarios de cooperativas (%)" = "part_coop",
           "Superficie cosechada mediana (ha)" = "ha_cosechada", "Edad media (años)" = "edad")
PERFIL_VARS <- c("Asociados" = "asociado", "Usan fertilizantes" = "fertilizantes", "Cultivos con riego" = "riego",
                 "Venden a mercados regionales" = "vende_regional", "Recibieron capacitación" = "capacitacion",
                 "Asistencia técnica" = "asistencia", "Arriendan tierra" = "arrienda", "Secundaria completa o más" = "secundaria",
                 "Lengua materna nativa" = "lengua_nativa", "Productoras mujeres" = "mujer")

`%||%` <- function(a, b) if (is.null(a)) b else a
num  <- function(x, k = 1) formatC(x, format = "f", digits = k, big.mark = ",")
pct  <- function(x, k = 1) paste0(num(x, k), " %")
ent  <- function(x) format(round(x), big.mark = ",")
lay <- function(p, ytitle = NULL, xtitle = NULL, ...) p |>
  layout(yaxis = list(title = ytitle %||% "", gridcolor = "#E5E7EB", zeroline = FALSE), xaxis = list(title = xtitle %||% "", gridcolor = "#F3F4F6"),
         legend = list(orientation = "h", y = -0.2), margin = list(l = 10, r = 10, t = 10, b = 10), font = list(size = 13),
         hoverlabel = list(bgcolor = "#111827", font = list(color = "white", size = 13)), ...) |>
  config(displayModeBar = FALSE)
nota <- function(...) p(class = "text-muted small mb-0", ...)
tabla_dt <- function(d, ...) datatable(d, rownames = FALSE, options = list(dom = "t", ordering = FALSE, ...), class = "compact stripe")

tema <- bs_theme(version = 5, primary = AZUL, "navbar-bg" = "#0B3D5C", bg = "#FFFFFF", fg = "#111827",
                 base_font = font_collection("Inter", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"))

# Mapa de burbujas (centroides de la ENA) ------------------------------------------------------------
mapa <- function(var, sel = NULL, fuente = "mapa") {
  d <- DEPS |> mutate(v = .data[[var]], borde = if_else(DEPARTAMENTO %in% sel, 3, 0.6))
  nombre <- names(INDIC)[INDIC == var]
  plot_ly(d, type = "scattergeo", mode = "markers+text", lat = ~lat, lon = ~lon, customdata = ~DEPARTAMENTO, source = fuente,
          text = ~DEPARTAMENTO, textposition = "top center", textfont = list(size = 10, color = "#374151"),
          marker = list(size = ~pmax(14, sqrt(productores) / 4), color = ~v, colorscale = "Viridis", reversescale = FALSE, opacity = 0.9,
                        line = list(color = "#111827", width = ~borde), colorbar = list(title = list(text = nombre, side = "right"), thickness = 12, len = 0.8)),
          hovertemplate = paste0("<b>%{customdata}</b><br>", nombre, ": %{marker.color:.1f}<extra></extra>")) |>
    layout(geo = list(scope = "south america", projection = list(type = "mercator"), showcountries = TRUE, countrycolor = "#9CA3AF",
                      showland = TRUE, landcolor = "#F3F4F6", showocean = TRUE, oceancolor = "#EAF4FB", showlakes = TRUE, lakecolor = "#EAF4FB",
                      lataxis = list(range = c(-18.8, 0.2)), lonaxis = list(range = c(-82, -68.4)), resolution = 50),
           margin = list(l = 0, r = 0, t = 0, b = 0), dragmode = FALSE, clickmode = "event") |>
    config(displayModeBar = FALSE, scrollZoom = FALSE)
}

# ---- Interfaz -----------------------------------------------------------------------------------------
ui <- page_navbar(
  title = "Crédito agrario en el Perú · ENA 2016–2025", theme = tema, fillable = FALSE, id = "nav",
  header = tagList(plotly:::plotlyMainBundle(),   # carga plotly.js al inicio (evita gráficos en blanco en la versión web)
                  tags$style(HTML(".bslib-value-box .value-box-value{font-size:1.7rem} .card-header{font-weight:600} .small{font-size:.85rem}
                            .resumen li{margin-bottom:.35rem} .navbar-brand{font-weight:700}"))),

  nav_panel("Panorama", icon = bs_icon("speedometer2"),
    layout_column_wrap(width = 1/4, fill = FALSE,
      value_box("Acceso al crédito (2025)", uiOutput("vb_acceso"), showcase = bs_icon("cash-coin"), theme = "primary", p("solicitaron y obtuvieron, ponderado")),
      value_box("Solicitaron crédito", pct(PERU$solicitud), showcase = bs_icon("pencil-square"), theme = "light", p("de todos los productores, 2016–2025")),
      value_box("Aprobados", pct(PERU$aprobacion), showcase = bs_icon("check2-circle"), theme = "light", p("de quienes pidieron: la barrera está antes de pedir")),
      value_box("Prestamista público (2025)", uiOutput("vb_publico"), showcase = bs_icon("bank"), theme = "light", p("de los prestatarios usó Agrobanco o el Estado"))),
    layout_columns(col_widths = c(7, 5),
      card(full_screen = TRUE, card_header("Mapa: elige un indicador y haz clic en un departamento para ver su ficha"),
           selectInput("map_var", NULL, INDIC, selected = "acceso", width = "100%"),
           plotlyOutput("g_mapa", height = 520),
           nota("Cada punto es un departamento (centro de sus zonas encuestadas); el tamaño indica cuántos productores tiene la muestra.")),
      card(card_header("¿Cuántos tienen crédito y cuántos lo piden?"),
           radioButtons("pan_reg", NULL, c("Nacional", "Costa", "Sierra", "Selva"), inline = TRUE),
           plotlyOutput("g_acceso", height = 300),
           nota("Sólida: solicitaron y obtuvieron. Discontinua: solicitaron. Ponderado."),
           hr(),
           tags$ul(class = "resumen mb-0",
             tags$li(strong("1 de cada 10"), " productores obtiene crédito; casi todos los que lo piden lo reciben."),
             tags$li("La ", strong("costa"), " duplica el acceso de la ", strong("sierra"), "."),
             tags$li("Estar ", strong("asociado"), " es lo más ligado al crédito (odds ×2)."),
             tags$li("Cuando ", strong("Agrobanco"), " cayó en 2019, nadie lo reemplazó."))))),

  nav_panel("Departamento", icon = bs_icon("geo-alt"),
    layout_sidebar(
      sidebar = sidebar(width = 290, title = "Elige un departamento",
        selectInput("dep", NULL, DEPTOS, selected = "Puno"),
        plotlyOutput("g_mapa_mini", height = 330),
        nota("También puedes hacer clic en el mapa.")),
      uiOutput("dep_titulo"),
      layout_column_wrap(width = 1/4, fill = FALSE,
        value_box("Acceso al crédito", uiOutput("vb_d_acceso"), showcase = bs_icon("cash-stack"), theme = "primary"),
        value_box("Solicitaron crédito", uiOutput("vb_d_sol"), showcase = bs_icon("pencil-square"), theme = "light"),
        value_box("Brecha de propensión", uiOutput("vb_d_brecha"), showcase = bs_icon("people"), theme = "light"),
        value_box("Puesto en acceso", uiOutput("vb_d_rank"), showcase = bs_icon("trophy"), theme = "light")),
      layout_columns(col_widths = c(5, 7),
        card(card_header("Lo que dice el estudio sobre este departamento"), uiOutput("dep_resumen")),
        card(card_header("Acceso y solicitud por año frente al Perú"), plotlyOutput("g_d_anio", height = 330))),
      layout_columns(col_widths = c(6, 6),
        card(card_header("¿Quién le presta? (prestatarios por cada 100 productores)"),
             radioButtons("d_mix_modo", NULL, c("Por año", "Frente al Perú"), inline = TRUE),
             plotlyOutput("g_d_mix", height = 320)),
        card(card_header("Perfil de sus productores frente al Perú (%)"), plotlyOutput("g_d_perfil", height = 360))),
      layout_columns(col_widths = c(7, 5),
        card(card_header("Escenarios: tasa de acceso simulada si los productores que no tienen la condición la tuvieran"),
             plotlyOutput("g_d_esc", height = 320),
             nota("Simulación del modelo con todos los productores depurados del departamento, ponderada. No es un efecto causal.")),
        card(card_header("Ranking del departamento en cada indicador"), DTOutput("t_d_rank"))))),

  nav_panel("Comparar", icon = bs_icon("bar-chart-steps"),
    layout_sidebar(
      sidebar = sidebar(width = 290, title = "Compara hasta 4 departamentos",
        selectizeInput("cmp", NULL, DEPTOS, selected = c("Puno", "Cusco", "Arequipa", "Tumbes"), multiple = TRUE, options = list(maxItems = 4)),
        checkboxGroupInput("cmp_vars", "Indicadores", INDIC[1:9], selected = INDIC[c(1, 2, 3, 4, 9)])),
      card(card_header("Indicadores seleccionados (la línea gris es el Perú)"), plotlyOutput("g_cmp", height = 380)),
      layout_columns(col_widths = c(6, 6),
        card(card_header("Acceso al crédito por año"), plotlyOutput("g_cmp_anio", height = 320)),
        card(card_header("Tabla comparativa"), DTOutput("t_cmp"))))),

  nav_panel("¿Quién presta?", icon = bs_icon("building"),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Prestatarios por tipo de prestamista, por cada 100 productores"), plotlyOutput("g_tipos", height = 340),
           nota("Público: Agrobanco y programas del Estado. Privado regulado: bancos, cajas rurales y financieras.")),
      card(card_header("Cuando Agrobanco cayó, nadie lo reemplazó"), plotlyOutput("g_crisis", height = 340),
           nota("Productores con perfil parecido al de los clientes de Agrobanco frente al resto. Sólida: cualquier prestamista; punteada: Agrobanco."))),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Participación de cada prestamista por departamento (%)"), plotlyOutput("g_pres_dep", height = 520)),
      card(card_header("¿A quién atiende cada prestamista?"), DTOutput("t_perfil"),
           nota("Clientes con un solo tipo de prestamista, ponderado. Probabilidad predicha: probabilidad de tener crédito según el modelo.")))),

  nav_panel("Simulador", icon = bs_icon("bullseye"),
    layout_sidebar(
      sidebar = sidebar(width = 300,
        sliderInput("cobertura", "Un programa atiende al … de productores con mayor probabilidad", min = 5, max = 50, value = 20, step = 5, post = " %"),
        sliderInput("umbral", "Umbral de probabilidad para la brecha", min = 0.05, max = 0.50, value = 0.175, step = 0.025),
        selectInput("sim_ambito", "Ámbito", c("Nacional", "Costa", "Sierra", "Selva", DEPTOS)),
        nota("Calculado con los 9,969 productores de prueba, que el modelo no vio al entrenar. En departamentos pequeños el resultado es más incierto.")),
      layout_column_wrap(width = 1/3, fill = FALSE,
        value_box("Captaría a", uiOutput("vb_captados"), showcase = bs_icon("funnel"), theme = "primary", p("de quienes tienen crédito")),
        value_box("Frente al azar", uiOutput("vb_lift"), showcase = bs_icon("graph-up-arrow"), theme = "light"),
        value_box("Brecha con este umbral", uiOutput("vb_brecha"), showcase = bs_icon("person-x"), theme = "light", uiOutput("vb_brecha_sub"))),
      card(card_header("Curva de ganancia"), plotlyOutput("g_ganancia", height = 330), nota("Discontinua: elegir al azar. Punto: cobertura elegida.")))),

  nav_panel("Escenarios", icon = bs_icon("sliders"),
    layout_columns(col_widths = c(7, 5),
      card(card_header("Tasa de acceso simulada por escenario"), radioButtons("esc_reg", NULL, c("Nacional", "Costa", "Sierra", "Selva"), inline = TRUE),
           plotlyOutput("g_escenarios", height = 360),
           nota(strong("Ojo: "), "son simulaciones del modelo, no efectos causales. Barras: intervalo bootstrap del 95 %.")),
      card(card_header("Programa con presupuesto: ¿a quién asociar?"), DTOutput("t_asig"),
           nota("Nuevos accesos esperados (conjunto de prueba). Un modelo elige y otro independiente evalúa."), hr(), DTOutput("t_pond")))),

  nav_panel("El modelo", icon = bs_icon("cpu"),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Importancia de las variables (SHAP)"), plotlyOutput("g_shap", height = 380)),
      card(card_header("Efecto en la probabilidad de tener crédito (puntos porcentuales)"), plotlyOutput("g_efectos", height = 380))),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Cinco modelos rinden casi igual (AUC-ROC, IC 95 %)"), plotlyOutput("g_bench", height = 300)),
      card(card_header("Validación fuera de muestra"), DTOutput("t_valid")))),

  nav_panel("Datos", icon = bs_icon("table"),
    card(card_header("Indicadores de los 24 departamentos (ponderados, 196,566 productores depurados)"),
         downloadButton("descargar", "Descargar CSV", class = "btn-sm mb-2", style = "width:180px"),
         DTOutput("t_datos"))),

  nav_panel("Acerca del estudio", icon = bs_icon("info-circle"),
    layout_columns(col_widths = c(7, 5),
      card(card_header("El estudio"),
           p("Modelo de clasificación del acceso al crédito (solicitó y obtuvo crédito en los últimos 12 meses) de pequeños y medianos productores agropecuarios, con la Encuesta Nacional Agropecuaria (ENA) del INEI, rondas 2016, 2017, 2019 y 2022–2025."),
           tags$ul(
             tags$li("Muestra de modelado: 49,837 productores; comprobaciones con los 196,566 productores depurados."),
             tags$li("XGBoost con 14 variables, validación cruzada agrupada por conglomerado; AUC-ROC 0.798 en conglomerados no vistos."),
             tags$li("Comparado con regresión logística, elastic net, bosque aleatorio y modelo aditivo: todos rinden casi igual."),
             tags$li("Los escenarios son simulaciones del modelo: indican asociaciones, no efectos causales.")),
           p("Autores: Roberth Carlos Gonzales Mauricio y Cesia Belén Gómez Flores, Facultad de Ingeniería Estadística e Informática, Universidad Nacional del Altiplano (Puno).")),
      card(card_header("Código y datos"),
           p("Todo el análisis está hecho en R y es reproducible: scripts, datos depurados, informe en Quarto y artículo."),
           tags$a(href = "https://github.com/ROBERTHGONZALES/credito-agro-ena-r", target = "_blank", class = "btn btn-primary", bs_icon("github"), " Repositorio en GitHub"),
           hr(), nota("Fuente: INEI, Encuesta Nacional Agropecuaria (microdatos públicos). Elaboración propia.")))),

  nav_spacer(),
  nav_item(tags$span(class = "text-white-50 small", "Fuente: INEI · ENA · UNA Puno"))
)

# ---- Servidor ----------------------------------------------------------------------------------------
server <- function(input, output, session) {
  output$vb_acceso  <- renderUI(pct(acceso$acceso[acceso$REGION == "Nacional" & acceso$ANIO == max(ANIOS)]))
  output$vb_publico <- renderUI(pct(prest$part_pub[prest$ANIO == max(prest$ANIO)], 0))

  # Mapas y selección por clic
  output$g_mapa <- renderPlotly(mapa(input$map_var, input$dep, "mapa") |> event_register("plotly_click"))
  output$g_mapa_mini <- renderPlotly(mapa("acceso", input$dep, "mapa_mini") |> hide_colorbar() |> event_register("plotly_click"))
  observeEvent(event_data("plotly_click", source = "mapa"), {
    d <- event_data("plotly_click", source = "mapa")$customdata
    if (length(d) && d %in% DEPTOS) { updateSelectInput(session, "dep", selected = d); nav_select("nav", "Departamento") }
  })
  observeEvent(event_data("plotly_click", source = "mapa_mini"), {
    d <- event_data("plotly_click", source = "mapa_mini")$customdata
    if (length(d) && d %in% DEPTOS) updateSelectInput(session, "dep", selected = d)
  })

  output$g_acceso <- renderPlotly({
    a <- acceso |> filter(REGION %in% unique(c("Nacional", input$pan_reg))); p <- plot_ly()
    for (r in unique(a$REGION)) {
      ar <- a |> filter(REGION == r)
      p <- p |> add_trace(x = ar$ANIO, y = ar$acceso, type = "scatter", mode = "lines+markers", name = paste(r, "· obtuvo"),
                          line = list(color = COL_R[[r]], width = 3), marker = list(color = COL_R[[r]], size = 7),
                          hovertemplate = paste0(r, " %{x}: %{y:.1f} %<extra></extra>")) |>
        add_trace(x = ar$ANIO, y = ar$solicitud, type = "scatter", mode = "lines", name = paste(r, "· solicitó"),
                  line = list(color = COL_R[[r]], dash = "dash", width = 2), hovertemplate = paste0(r, " %{x}: %{y:.1f} % solicitó<extra></extra>"))
    }
    lay(p, "% de productores")
  })

  # ---- Ficha del departamento -------------------------------------------------------------------------
  D <- reactive(DEPS |> filter(DEPARTAMENTO == input$dep))
  rank_de <- function(var, desc = TRUE) { v <- DEPS[[var]]; r <- rank(if (desc) -v else v, ties.method = "min"); r[DEPS$DEPARTAMENTO == input$dep] }
  output$dep_titulo <- renderUI(h3(class = "mt-1 mb-3", input$dep, tags$small(class = "text-muted", paste0(" · región principal: ", D()$region, " · ", ent(D()$productores), " productores encuestados"))))
  output$vb_d_acceso <- renderUI(tagList(pct(D()$acceso), tags$div(class = "small", paste("Perú:", pct(PERU$acceso)))))
  output$vb_d_sol    <- renderUI(tagList(pct(D()$solicitud), tags$div(class = "small", paste("aprobados:", pct(D()$aprobacion, 0)))))
  output$vb_d_brecha <- renderUI(tagList(pct(D()$brecha), tags$div(class = "small", sprintf("IC 95 %%: %.0f–%.0f %%", D()$brecha_inf, D()$brecha_sup))))
  output$vb_d_rank   <- renderUI(tagList(paste0(rank_de("acceso"), "º de 24"), tags$div(class = "small", "1º = mayor acceso")))

  output$dep_resumen <- renderUI({
    d <- D()
    mix <- c("Público nacional" = d$part_pub, "Caja municipal" = d$part_cmac, "Privado regulado" = d$part_priv, "Cooperativa u ONG" = d$part_coop, "Informal" = d$part_inf)
    e <- dep_esc |> filter(DEPARTAMENTO == input$dep) |> arrange(desc(ganancia))
    e1 <- e |> filter(escenario %in% ESC_N[1:4]) |> slice(1)
    comp <- function(v, nacional) if (v > nacional * 1.1) "por encima" else if (v < nacional * 0.9) "por debajo" else "cerca"
    efecto <- if (is.na(d$shap)) NULL else if (d$shap > 0.1) "el departamento suma probabilidad por sí mismo (efecto propio positivo en el modelo)" else
      if (d$shap < -0.1) "el departamento resta probabilidad por sí mismo (efecto propio negativo en el modelo)" else "el departamento casi no tiene efecto propio en el modelo"
    tags$ul(class = "resumen mb-0",
      tags$li(sprintf("Acceso de %s, %s del promedio nacional (%s); puesto %dº de 24.", pct(d$acceso), comp(d$acceso, PERU$acceso), pct(PERU$acceso), rank_de("acceso"))),
      tags$li(sprintf("Pidió crédito el %s y se aprobó al %s de quienes pidieron.", pct(d$solicitud), pct(d$aprobacion, 0))),
      tags$li(sprintf("Prestamista más usado: %s (%s de los prestatarios).", names(which.max(mix)), pct(max(mix), 0))),
      tags$li(sprintf("Brecha de propensión: %s de sus productores tiene perfil de prestatario sin crédito (puesto %dº).", pct(d$brecha), rank_de("brecha"))),
      tags$li(sprintf("Asociados: %s (Perú %s); usan fertilizantes: %s (Perú %s).", pct(d$asociado), pct(PERU$asociado), pct(d$fertilizantes, 0), pct(PERU$fertilizantes, 0))),
      tags$li(sprintf("Escenario con mayor ganancia: %s, de %s a %s (+%s puntos).", tolower(e1$escenario), pct(e1$base), pct(e1$simulada), num(e1$ganancia))),
      if (!is.null(efecto)) tags$li(paste0("A igualdad de características, ", efecto, ".")))
  })

  output$g_d_anio <- renderPlotly({
    d <- dep_anio |> filter(DEPARTAMENTO == input$dep) |> arrange(ANIO); n <- acceso |> filter(REGION == "Nacional")
    plot_ly() |>
      add_trace(x = d$ANIO, y = d$acceso, type = "bar", name = paste(input$dep, "· obtuvo"), marker = list(color = AZUL), hovertemplate = "%{x}: %{y:.1f} %<extra></extra>") |>
      add_trace(x = d$ANIO, y = d$solicitud, type = "scatter", mode = "markers", name = paste(input$dep, "· solicitó"), marker = list(color = NARANJA, size = 10, symbol = "diamond"),
                hovertemplate = "%{x}: %{y:.1f} % solicitó<extra></extra>") |>
      add_trace(x = n$ANIO, y = n$acceso, type = "scatter", mode = "lines+markers", name = "Perú · obtuvo", line = list(color = "#1F2937", width = 2),
                hovertemplate = "Perú %{x}: %{y:.1f} %<extra></extra>") |> lay("% de productores")
  })

  output$g_d_mix <- renderPlotly({
    cols <- c(tipo_publico = "Público nacional", tipo_caja_municipal = "Caja municipal", tipo_privado_regulado = "Privado regulado", tipo_cooperativa_ong = "Cooperativa u ONG", tipo_informal = "Informal")
    if (input$d_mix_modo == "Por año") {
      dd <- dep_anio |> filter(DEPARTAMENTO == input$dep) |> select(ANIO, all_of(names(cols))) |> pivot_longer(-ANIO) |> mutate(tipo = cols[name])
      plot_ly(dd, x = ~ANIO, y = ~value, color = ~tipo, colors = COL_T, type = "bar", hovertemplate = "%{x}: %{y:.1f} por cada 100<extra>%{fullData.name}</extra>") |>
        lay("Por cada 100 productores", barmode = "stack")
    } else {
      dd <- bind_rows(dep_anio |> filter(DEPARTAMENTO == input$dep) |> summarise(across(all_of(names(cols)), mean)) |> mutate(quien = input$dep),
                      prest |> summarise(tipo_publico = mean(por100_pub), tipo_caja_municipal = mean(por100_cmac), tipo_privado_regulado = mean(por100_priv),
                                         tipo_cooperativa_ong = mean(por100_coop), tipo_informal = mean(por100_inf)) |> mutate(quien = "Perú")) |>
        pivot_longer(-quien) |> mutate(tipo = factor(cols[name], unname(cols)))
      plot_ly(dd, x = ~value, y = ~tipo, color = ~quien, colors = c(AZUL, GRIS), type = "bar", orientation = "h",
              hovertemplate = "%{y}: %{x:.1f} por cada 100<extra>%{fullData.name}</extra>") |> lay(NULL, "Promedio por cada 100 productores (todas las rondas)", barmode = "group")
    }
  })

  output$g_d_perfil <- renderPlotly({
    dd <- tibble(var = names(PERFIL_VARS), dep = unlist(D()[PERFIL_VARS]), peru = unlist(PERU[PERFIL_VARS])) |> mutate(var = factor(var, rev(names(PERFIL_VARS))))
    plot_ly(dd) |>
      add_segments(x = ~peru, xend = ~dep, y = ~var, yend = ~var, line = list(color = "#D1D5DB", width = 3), showlegend = FALSE, hoverinfo = "skip") |>
      add_markers(x = ~peru, y = ~var, name = "Perú", marker = list(color = GRIS, size = 10), hovertemplate = "Perú · %{y}: %{x:.1f} %<extra></extra>") |>
      add_markers(x = ~dep, y = ~var, name = input$dep, marker = list(color = AZUL, size = 12), hovertemplate = paste0(input$dep, " · %{y}: %{x:.1f} %<extra></extra>")) |>
      lay(NULL, "% de productores (ponderado)")
  })

  output$g_d_esc <- renderPlotly({
    e <- dep_esc |> filter(DEPARTAMENTO == input$dep) |> mutate(escenario = factor(escenario, rev(ESC_N)))
    base <- e$base[1]
    plot_ly(e, x = ~simulada, y = ~escenario, type = "bar", orientation = "h", marker = list(color = AZUL), text = ~sprintf("+%.1f", ganancia),
            textposition = "outside", cliponaxis = FALSE, hovertemplate = "%{y}: %{x:.1f} %<extra></extra>") |>
      lay(NULL, "Tasa simulada (%)", showlegend = FALSE,
          shapes = list(list(type = "line", x0 = base, x1 = base, yref = "paper", y0 = 0, y1 = 1, line = list(color = NARANJA, dash = "dash", width = 2))),
          annotations = list(list(x = base, y = 1, yref = "paper", text = sprintf("<b>Hoy: %.1f %%</b>", base), showarrow = FALSE, xanchor = "center", yanchor = "bottom", yshift = 2,
                                  font = list(color = "white", size = 13), bgcolor = NARANJA, borderpad = 4))) |>
      layout(margin = list(t = 40)) |>
      layout(xaxis = list(range = c(0, max(e$simulada) * 1.18)))
  })

  output$t_d_rank <- renderDT({
    t <- tibble(Indicador = names(INDIC)[1:12], var = unname(INDIC[1:12])) |>
      mutate(Valor = vapply(var, function(v) num(D()[[v]]), ""), `Perú` = vapply(var, function(v) if (v %in% names(PERU) && !is.na(PERU[[v]])) num(PERU[[v]]) else "–", ""),
             Puesto = vapply(var, function(v) paste0(rank_de(v), "º"), "")) |> select(-var)
    tabla_dt(t, pageLength = 15)
  })

  # ---- Comparar ----------------------------------------------------------------------------------------
  output$g_cmp <- renderPlotly({
    req(length(input$cmp) > 0, length(input$cmp_vars) > 0)
    vs <- input$cmp_vars
    dd <- DEPS |> filter(DEPARTAMENTO %in% input$cmp) |> select(DEPARTAMENTO, all_of(vs)) |> pivot_longer(-DEPARTAMENTO) |>
      mutate(ind = factor(names(INDIC)[match(name, INDIC)], names(INDIC)[match(vs, INDIC)]), DEPARTAMENTO = factor(DEPARTAMENTO, input$cmp))
    pe <- tibble(name = vs, ind = factor(names(INDIC)[match(vs, INDIC)], levels(dd$ind)), v = vapply(vs, function(v) if (v %in% names(PERU) && !is.na(PERU[[v]])) PERU[[v]] else NA_real_, 0))
    p <- plot_ly(dd, x = ~ind, y = ~value, color = ~DEPARTAMENTO, colors = COL_CMP[seq_along(input$cmp)], type = "bar",
                 hovertemplate = "%{x}: %{y:.1f}<extra>%{fullData.name}</extra>")
    p |> add_trace(data = pe |> filter(!is.na(v)), x = ~ind, y = ~v, type = "scatter", mode = "markers", inherit = FALSE, name = "Perú",
                   marker = list(symbol = "line-ew-open", size = 40, color = "#6B7280", line = list(width = 3)), hovertemplate = "Perú: %{y:.1f}<extra></extra>") |>
      lay("%", barmode = "group")
  })
  output$g_cmp_anio <- renderPlotly({
    req(length(input$cmp) > 0); p <- plot_ly()
    for (i in seq_along(input$cmp)) {
      d <- dep_anio |> filter(DEPARTAMENTO == input$cmp[i]) |> arrange(ANIO)
      p <- p |> add_trace(x = d$ANIO, y = d$acceso, type = "scatter", mode = "lines+markers", name = input$cmp[i], line = list(color = COL_CMP[i], width = 3),
                          marker = list(color = COL_CMP[i]), hovertemplate = paste0(input$cmp[i], " %{x}: %{y:.1f} %<extra></extra>"))
    }
    n <- acceso |> filter(REGION == "Nacional")
    p |> add_trace(x = n$ANIO, y = n$acceso, type = "scatter", mode = "lines", name = "Perú", line = list(color = GRIS, dash = "dash")) |> lay("% con crédito")
  })
  output$t_cmp <- renderDT({
    req(length(input$cmp) > 0)
    t <- DEPS |> filter(DEPARTAMENTO %in% input$cmp) |> mutate(DEPARTAMENTO = factor(DEPARTAMENTO, input$cmp)) |> arrange(DEPARTAMENTO) |>
      transmute(Departamento = as.character(DEPARTAMENTO), Región = region, Productores = ent(productores), Acceso = pct(acceso), Solicitud = pct(solicitud),
                Brecha = pct(brecha), Asociados = pct(asociado), `Ha cosechadas` = num(ha_cosechada, 2))
    tabla_dt(t)
  })

  # ---- ¿Quién presta? ------------------------------------------------------------------------------
  output$g_tipos <- renderPlotly({
    l <- prest |> select(ANIO, starts_with("por100_")) |> pivot_longer(-ANIO) |> mutate(tipo = TIPOS[sub("por100_", "", name)])
    plot_ly(l, x = ~ANIO, y = ~value, color = ~tipo, colors = COL_T, type = "scatter", mode = "lines+markers", line = list(width = 3),
            hovertemplate = "%{x} · %{y:.1f} por cada 100<extra>%{fullData.name}</extra>") |> lay("Por cada 100 productores")
  })
  output$g_crisis <- renderPlotly({
    cr <- crisis |> mutate(g = if_else(grepl("Agrobanco", grupo), "Perfil tipo Agrobanco", "Resto"))
    cols <- c("Perfil tipo Agrobanco" = AZUL, "Resto" = GRIS); p <- plot_ly()
    for (gg in names(cols)) {
      cg <- cr |> filter(g == gg)
      p <- p |> add_trace(x = cg$ANIO, y = cg$acceso, type = "scatter", mode = "lines+markers", name = paste(gg, "· cualquier prestamista"),
                          line = list(color = cols[[gg]], width = 3), marker = list(color = cols[[gg]]), hovertemplate = paste0(gg, " %{x}: %{y:.1f} %<extra></extra>")) |>
        add_trace(x = cg$ANIO, y = cg$pct_agrobanco, type = "scatter", mode = "lines", name = paste(gg, "· Agrobanco"),
                  line = list(color = cols[[gg]], dash = "dot", width = 2), hovertemplate = paste0(gg, " %{x}: %{y:.1f} % de Agrobanco<extra></extra>"))
    }
    lay(p, "% de productores")
  })
  output$g_pres_dep <- renderPlotly({
    dd <- dep_pres |> filter(DEPARTAMENTO != "Callao") |> arrange(part_pub) |> mutate(DEPARTAMENTO = factor(DEPARTAMENTO, DEPARTAMENTO)) |>
      select(DEPARTAMENTO, part_pub, part_cmac, part_priv, part_coop, part_inf) |> pivot_longer(-DEPARTAMENTO) |>
      mutate(tipo = factor(TIPOS[sub("part_", "", name)], unname(TIPOS)))
    plot_ly(dd, x = ~value, y = ~DEPARTAMENTO, color = ~tipo, colors = COL_T, type = "bar", orientation = "h",
            hovertemplate = "%{y}: %{x:.0f} %<extra>%{fullData.name}</extra>") |> lay(NULL, "% de los prestatarios", barmode = "stack")
  })
  output$t_perfil <- renderDT({
    t <- pperfil |> transmute(Prestamista = tipo, Clientes = ent(clientes), `Prob. predicha` = pct(prob_predicha), `Ha cosech.` = num(ha_cosechada_mediana),
                              Asociados = pct(asociado, 0), Sierra = pct(sierra, 0), Selva = pct(selva, 0), `Uso en insumos` = pct(uso_insumos_agricolas, 0))
    tabla_dt(t)
  })

  # ---- Simulador ---------------------------------------------------------------------------------------
  psel <- reactive({
    a <- input$sim_ambito
    if (a == "Nacional") pred else if (a %in% c("Costa", "Sierra", "Selva")) pred |> filter(REGION == a) else pred |> filter(DEPARTAMENTO == a)
  })
  sim <- reactive({
    d <- psel() |> arrange(desc(p)); req(nrow(d) > 0, sum(d$y) > 0)
    k <- ceiling(nrow(d) * input$cobertura / 100); capt <- sum(d$y[seq_len(k)]) / sum(d$y)
    br <- d$p >= input$umbral & d$y == 0
    list(capt = capt, lift = capt / (input$cobertura / 100), brecha = mean(br), sol = if (any(br)) mean(d$solicito[br], na.rm = TRUE) else NA,
         prec = if (any(d$p >= input$umbral)) mean(d$y[d$p >= input$umbral]) else NA, d = d)
  })
  output$vb_captados <- renderUI(pct(100 * sim()$capt, 0))
  output$vb_lift <- renderUI(paste0(num(sim()$lift), " veces"))
  output$vb_brecha <- renderUI(pct(100 * sim()$brecha))
  output$vb_brecha_sub <- renderUI(p(sprintf("de los productores (%s de prueba); solo el %.1f %% de ellos solicitó crédito.", ent(nrow(sim()$d)), 100 * sim()$sol)))
  output$g_ganancia <- renderPlotly({
    d <- sim()$d; n <- nrow(d); cs <- cumsum(d$y) / sum(d$y)
    idx <- unique(pmax(1, round(seq(0.01, 1, by = 0.01) * n)))
    plot_ly(x = 100 * idx / n, y = 100 * cs[idx], type = "scatter", mode = "lines", name = "Modelo", line = list(color = AZUL, width = 3),
            hovertemplate = "Atender %{x:.0f} % → capta %{y:.0f} %<extra></extra>") |>
      add_trace(x = c(0, 100), y = c(0, 100), mode = "lines", name = "Azar", line = list(color = GRIS, dash = "dash"), hoverinfo = "skip") |>
      add_trace(x = input$cobertura, y = 100 * sim()$capt, mode = "markers", name = "Elegido", marker = list(color = NARANJA, size = 14)) |>
      lay("% de productores con crédito captados", "% de productores atendidos")
  })

  # ---- Escenarios --------------------------------------------------------------------------------------
  output$g_escenarios <- renderPlotly({
    e <- esc_ic |> filter(ambito == input$esc_reg) |>
      mutate(esc = recode(escenario, "Venta a mercados regionales/Lima" = "Venta a mercados", "Las cuatro palancas" = "Las cuatro acciones"), esc = factor(esc, rev(ESC_N)))
    base <- e$base[1]
    plot_ly(e, x = ~simulada, y = ~esc, type = "bar", orientation = "h", marker = list(color = AZUL),
            error_x = list(type = "data", symmetric = FALSE, array = ~sim_sup - simulada, arrayminus = ~simulada - sim_inf, color = "#111827"),
            hovertemplate = "%{y}: %{x:.1f} %<extra></extra>") |>
      lay(NULL, "Tasa de acceso simulada (%)", showlegend = FALSE,
          shapes = list(list(type = "line", x0 = base, x1 = base, yref = "paper", y0 = 0, y1 = 1, line = list(color = NARANJA, dash = "dash", width = 2))),
          annotations = list(list(x = base, y = 1, yref = "paper", text = sprintf("<b>Hoy: %.1f %%</b>", base), showarrow = FALSE, xanchor = "center", yanchor = "bottom", yshift = 2,
                                  font = list(color = "white", size = 13), bgcolor = NARANJA, borderpad = 4))) |>
      layout(margin = list(t = 40))
  })
  output$t_asig <- renderDT({
    a <- asig |> mutate(regla = recode(regla, ganancia = "Por ganancia simulada", probabilidad = "Por mayor probabilidad", azar = "Al azar"),
                        v = sprintf("%.0f (%.0f–%.0f)", cruzado, inf, sup)) |> select(K, regla, v) |> pivot_wider(names_from = regla, values_from = v) |>
      rename(`Productores atendidos` = K)
    tabla_dt(a)
  })
  output$t_pond <- renderDT({
    t <- esc_pond |> transmute(Escenario = recode(escenario, "Base" = "Situación actual", "Venta a mercados regionales/Lima" = "Venta a mercados", "Las cuatro palancas" = "Las cuatro acciones"),
                               `Sin ponderar` = pct(sin_ponderar), Ponderada = pct(ponderado))
    tabla_dt(t)
  })

  # ---- Modelo ------------------------------------------------------------------------------------
  output$g_shap <- renderPlotly({
    s <- shap |> arrange(shap) |> mutate(etiqueta = factor(etiqueta, etiqueta))
    plot_ly(s, x = ~shap, y = ~etiqueta, type = "bar", orientation = "h", marker = list(color = AZUL), hovertemplate = "%{y}: %{x:.3f}<extra></extra>") |>
      lay(NULL, "SHAP absoluto medio (log-odds)")
  })
  output$g_efectos <- renderPlotly({
    e <- efectos |> arrange(efecto_pp) |> mutate(etiqueta = factor(etiqueta, etiqueta))
    plot_ly(e, x = ~efecto_pp, y = ~etiqueta, type = "bar", orientation = "h", text = ~tipo, textposition = "none",
            marker = list(color = ifelse(e$efecto_pp >= 0, AZUL, NARANJA)), hovertemplate = "%{y} (%{text}): %{x:+.1f} pp<extra></extra>") |> lay(NULL, "Puntos porcentuales")
  })
  output$g_bench <- renderPlotly({
    b <- bench |> mutate(modelo = recode(modelo, "Logística penalizada (elastic net)" = "Logística elastic net")) |> arrange(auc_roc) |> mutate(modelo = factor(modelo, modelo))
    plot_ly(b, x = ~auc_roc, y = ~modelo, type = "scatter", mode = "markers", marker = list(color = AZUL, size = 12),
            error_x = list(type = "data", symmetric = FALSE, array = ~auc_roc_sup - auc_roc, arrayminus = ~auc_roc - auc_roc_inf, color = AZUL),
            hovertemplate = "%{y}: %{x:.3f}<extra></extra>") |> lay(NULL, "AUC-ROC en el conjunto de prueba")
  })
  output$t_valid <- renderDT({
    v <- bind_rows(tibble(Prueba = "Conjunto de prueba (9,969 productores)", `AUC-ROC` = 0.798, `AUC-PR` = 0.367),
                   valid |> transmute(Prueba = recode(validacion, "Temporal: 2016-2023 -> 2024-2025" = "Entrenar 2016–2023, probar 2024–2025",
                                                      "Espacial: sin Costa" = "Dejando fuera la costa", "Espacial: sin Sierra" = "Dejando fuera la sierra",
                                                      "Espacial: sin Selva" = "Dejando fuera la selva"), `AUC-ROC` = round(auc_roc, 3), `AUC-PR` = round(auc_pr, 3)),
                   tibble(Prueba = "Todos los datos depurados (196,566)", `AUC-ROC` = 0.801, `AUC-PR` = 0.357))
    tabla_dt(v)
  })

  # ---- Datos ----------------------------------------------------------------------------------------
  tabla_datos <- reactive(perfil |> left_join(dep_brec |> select(DEPARTAMENTO, brecha, brecha_inf = inf, brecha_sup = sup), by = "DEPARTAMENTO") |>
    left_join(dep_pres |> select(DEPARTAMENTO, starts_with("part_")), by = "DEPARTAMENTO") |>
    select(-any_of(c("lat", "lon"))) |> mutate(across(where(is.numeric), ~ round(.x, 2))))
  output$t_datos <- renderDT(datatable(tabla_datos(), rownames = FALSE, filter = "top", class = "compact stripe",
                                       options = list(pageLength = 25, scrollX = TRUE, dom = "tip")))
  output$descargar <- downloadHandler(filename = function() "indicadores_departamentos_ENA.csv",
                                      content = function(f) utils::write.csv(tabla_datos(), f, row.names = FALSE, fileEncoding = "UTF-8"))
}

shinyApp(ui, server)
