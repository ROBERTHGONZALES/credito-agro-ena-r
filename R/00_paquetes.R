# 00 · Instala (si faltan) y carga las librerías del estudio en R.
paquetes <- c("tidyverse", "nanoparquet", "caret", "xgboost", "easystats", "shapviz", "pROC", "PRROC", "patchwork",
              "glmnet", "ranger", "mgcv", "sandwich",                 # comparación de modelos y errores robustos (13, 14)
              "knitr", "rmarkdown",                                    # informes Quarto
              "shiny", "bslib", "bsicons", "plotly", "DT", "shinylive")   # dashboard y su versión web
lib <- Sys.getenv("R_LIBS_USER")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
faltan <- setdiff(paquetes, rownames(installed.packages()))
if (length(faltan)) install.packages(faltan, lib = lib, repos = "https://cloud.r-project.org", Ncpus = 10)
if ("easystats" %in% rownames(installed.packages())) {
  nucleo <- c("insight", "datawizard", "bayestestR", "parameters", "performance", "effectsize", "correlation", "modelbased", "report", "see")
  f2 <- setdiff(nucleo, rownames(installed.packages()))
  if (length(f2)) install.packages(f2, lib = lib, repos = "https://cloud.r-project.org", Ncpus = 10)
}
invisible(lapply(paquetes, function(p) suppressPackageStartupMessages(library(p, character.only = TRUE))))
