# Funciones y constantes compartidas por los scripts 01–07.
suppressPackageStartupMessages({
  library(tidyverse)
})
RAIZ <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), mustWork = FALSE)
if (is.na(RAIZ) || !dir.exists(file.path(RAIZ, "R"))) RAIZ <- getwd()
BASE <- file.path(RAIZ, "R")
DATOS <- file.path(BASE, "datos")
RES <- file.path(BASE, "resultados")
dir.create(DATOS, showWarnings = FALSE); dir.create(RES, showWarnings = FALSE)
SEMILLA <- 2026
OBJ <- "ACCESO_CREDITO"
CATEGORICAS <- c("REGION", "DEPARTAMENTO")
NO_PREDICTORES <- c("ANIO", "K_PROD", "GRUPO_CV", "FACTOR_EXP", "DISENO", OBJ, "ESTRATO", "FACTOR_EXP_MUESTRA", "CONJUNTO")
VERDE <- "#1b7f5a"; AZUL <- "#2563eb"; NARANJA <- "#ea580c"; GRIS <- "#64748b"

ETIQUETAS <- c(
  EDAD = "Edad", SEXO_MUJER = "Productora mujer", EDUCACION = "Nivel educativo", LENGUA_NATIVA = "Lengua materna nativa",
  EXPERIENCIA = "Años de experiencia", TAM_HOGAR = "Tamaño del hogar", VIVE_EN_PARCELA = "Vive en la parcela",
  SUP_TOTAL_HA = "Superficie total (ha)", N_PARCELAS = "Nº de parcelas", SUP_COSECHADA_HA = "Superficie cosechada (ha)",
  N_CULTIVOS = "Nº de cultivos", ARRIENDA_TIERRA = "Arrienda tierra", PCT_CULTIVOS_RIEGO = "% cultivos con riego",
  RIEGO_TECNIFICADO = "Riego tecnificado", PAGA_AGUA_RIEGO = "Paga agua de riego", USA_ABONOS = "Usa abonos",
  USA_FERTILIZANTES = "Usa fertilizantes", USA_PLAGUICIDAS = "Usa plaguicidas", ANALISIS_SUELO = "Análisis de suelo",
  VENDE_CULTIVOS = "Vende cultivos", PCT_CULTIVOS_VENDIDOS = "% cultivos vendidos",
  VENDE_AGROIND_EXTERIOR = "Vende a agroindustria/exterior", VENDE_LIMA_REGIONAL = "Vende a mercados regionales/Lima",
  CERTIFICACION = "Certificación de calidad", TIENE_PECUARIO = "Tiene ganado", N_ESPECIES_PECUARIAS = "Nº de especies pecuarias",
  ASOCIADO = "Asociado", COMISION_REGANTES = "Comisión de regantes", CAPACITACION = "Recibió capacitación",
  ASISTENCIA_TECNICA = "Asistencia técnica", PAGA_ASISTENCIA_TEC = "Paga asistencia técnica",
  USA_INFO_PRECIOS = "Usa información de precios", REGION = "Región natural", DEPARTAMENTO = "Departamento",
  MINERIA_CERCA = "Minería cerca")
DEPARTAMENTOS <- c("01" = "Amazonas", "02" = "Áncash", "03" = "Apurímac", "04" = "Arequipa", "05" = "Ayacucho", "06" = "Cajamarca",
  "07" = "Callao", "08" = "Cusco", "09" = "Huancavelica", "10" = "Huánuco", "11" = "Ica", "12" = "Junín", "13" = "La Libertad",
  "14" = "Lambayeque", "15" = "Lima", "16" = "Loreto", "17" = "Madre de Dios", "18" = "Moquegua", "19" = "Pasco", "20" = "Piura",
  "21" = "Puno", "22" = "San Martín", "23" = "Tacna", "24" = "Tumbes", "25" = "Ucayali")

cargar <- function() readRDS(file.path(DATOS, "muestra.rds"))
predictores_todos <- function(d) setdiff(names(d), NO_PREDICTORES)

# Matriz numérica para XGBoost: las categóricas pasan a columnas 0/1 (una por categoría).
# El atributo "variable" indica a qué variable original pertenece cada columna.
matriz <- function(d, vars) {
  partes <- lapply(vars, function(v) {
    if (is.factor(d[[v]])) {
      m <- model.matrix(~ x - 1, data.frame(x = d[[v]]))
      colnames(m) <- paste0(v, "_", levels(d[[v]]))
      m
    } else matrix(as.numeric(d[[v]]), ncol = 1, dimnames = list(NULL, v))
  })
  X <- do.call(cbind, partes)
  attr(X, "variable") <- rep(vars, vapply(partes, ncol, 1L))
  X
}

# Precisión media (AUC-PR), igual definición que average_precision_score de scikit-learn.
auc_pr <- function(y, p, w = rep(1, length(y))) {
  o <- order(-p); y <- y[o]; w <- w[o]; p <- p[o]
  tp <- cumsum(w * y); fp <- cumsum(w * (1 - y))
  ult <- !duplicated(p, fromLast = TRUE)
  prec <- (tp / (tp + fp))[ult]; rec <- (tp / sum(w * y))[ult]
  sum(diff(c(0, rec)) * prec)
}
auc_roc <- function(y, p) as.numeric(pROC::auc(pROC::roc(y, p, quiet = TRUE, direction = "<")))

metricas <- function(y, p, u) {
  yh <- as.integer(p >= u)
  tp <- sum(y == 1 & yh == 1); tn <- sum(y == 0 & yh == 0); fp <- sum(y == 0 & yh == 1); fn <- sum(y == 1 & yh == 0)
  prec <- if (tp + fp > 0) tp / (tp + fp) else 0
  rec <- tp / (tp + fn); esp <- tn / (tn + fp)
  den <- sqrt((tp + fp)) * sqrt((tp + fn)) * sqrt((tn + fp)) * sqrt((tn + fn))
  pe <- ((tp + fp) * (tp + fn) + (tn + fn) * (tn + fp)) / length(y)^2; po <- (tp + tn) / length(y)
  pc <- pmin(pmax(p, 1e-15), 1 - 1e-15)
  c("AUC-ROC" = if (length(unique(p)) > 1) auc_roc(y, p) else 0.5, "AUC-PR" = auc_pr(y, p),
    "Balanced accuracy" = (rec + esp) / 2, "F1 (con crédito)" = if (prec + rec > 0) 2 * prec * rec / (prec + rec) else 0,
    "Precisión" = prec, "Recall" = rec, "Especificidad" = esp,
    "MCC" = if (den > 0) (tp * tn - fp * fn) / den else 0, "Kappa" = (po - pe) / (1 - pe), "Accuracy" = po,
    "Brier" = mean((p - y)^2), "Log-loss" = -mean(y * log(pc) + (1 - y) * log(1 - pc)))
}

# Umbral que maximiza F1.
umbral_f1 <- function(y, p) {
  us <- seq(0.02, 0.8, by = 0.005)
  f1 <- vapply(us, function(u) metricas_f1(y, p, u), 0)
  us[which.max(f1)]
}
metricas_f1 <- function(y, p, u) {
  yh <- p >= u; tp <- sum(y == 1 & yh); if (tp == 0) return(0)
  pr <- tp / sum(yh); rc <- tp / sum(y == 1); 2 * pr * rc / (pr + rc)
}

tema <- function() theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 12),
                                                         plot.title.position = "plot")
guardar <- function(g, nombre, ancho = 8, alto = 4.5) ggsave(file.path(RES, nombre), g, width = ancho, height = alto, dpi = 150, bg = "white")
