# 01b · Extrae las preguntas de crédito de la ENA para los 196,566 productores depurados.
#   Entradas: data/etapas/08_limpio.parquet (población depurada) y data/etapas/06_productor_anio_2014_2025.parquet
#             (base productor-año con todas las variables; no se publica por su tamaño).
#   Salida:   data/etapas/10_credito_productor.parquet: ANIO, K_PROD, UBIGEO, P901 (solicitó), P902 (obtuvo),
#             P903_1..11 (quién prestó), P904_1..10 (uso del crédito) y P904A (razón de denegación).
#   Los scripts 13, 14 y 15 leen este archivo. En el repositorio público ya viene incluido, así que este paso
#   solo hace falta si se reconstruye todo desde los microdatos del INEI.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
suppressPackageStartupMessages(library(nanoparquet))
cols <- c("ANIO", "K_PROD", "UBIGEO", "P901", "P902", paste0("P903_", 1:11), paste0("P904_", 1:10), "P904A")
pa <- read_parquet(file.path(RAIZ, "data", "etapas", "06_productor_anio_2014_2025.parquet"), col_select = cols) |> as_tibble() |>
  mutate(ANIO = as.integer(ANIO))
lim <- read_parquet(file.path(RAIZ, "data", "etapas", "08_limpio.parquet"), col_select = c("ANIO", "K_PROD")) |> as_tibble() |> mutate(ANIO = as.integer(ANIO))
cred <- lim |> left_join(pa, by = c("ANIO", "K_PROD"))
stopifnot(nrow(cred) == 196566, !anyNA(cred$P901), !any(duplicated(cred[c("ANIO", "K_PROD")])))
write_parquet(cred, file.path(RAIZ, "data", "etapas", "10_credito_productor.parquet"))
cat("ok:", nrow(cred), "productores ·", ncol(cred), "columnas · solicitó", round(100 * mean(cred$P901 == 1), 1), "%\n")
