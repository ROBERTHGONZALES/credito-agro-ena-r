# 01 · Lee la muestra limpia (49,837 productores, 35 variables candidatas) y la prepara para R.
# Entrada: data/etapas/09_muestra_modelo.parquet (ya limpia, con partición fija entrenamiento / prueba por conglomerado).
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
library(nanoparquet)

d <- read_parquet(file.path(RAIZ, "data", "etapas", "09_muestra_modelo.parquet")) |>
  as_tibble() |>
  mutate(
    REGION = factor(REGION, levels = 1:3, labels = c("Costa", "Sierra", "Selva")),
    DEPARTAMENTO = factor(DEPARTAMENTOS[as.character(DEPARTAMENTO)]),
    CONJUNTO = factor(CONJUNTO, levels = c("entrenamiento", "prueba")),
    across(where(is.numeric) & !c(FACTOR_EXP, FACTOR_EXP_MUESTRA), as.numeric)
  )
stopifnot(!anyNA(d), nrow(d) == 49837)
saveRDS(d, file.path(DATOS, "muestra.rds"))

resumen <- d |> group_by(CONJUNTO) |>
  summarise(productores = n(), conglomerados = n_distinct(GRUPO_CV), con_credito = sum(ACCESO_CREDITO),
            pct_credito = round(100 * mean(ACCESO_CREDITO), 2),
            pct_credito_ponderado = round(100 * weighted.mean(ACCESO_CREDITO, FACTOR_EXP_MUESTRA), 2))
write_csv(resumen, file.path(RES, "01_resumen_muestra.csv"))
print(resumen)
cat("Conglomerados compartidos entre entrenamiento y prueba:",
    length(intersect(d$GRUPO_CV[d$CONJUNTO == "entrenamiento"], d$GRUPO_CV[d$CONJUNTO == "prueba"])), "\n")
cat("Predictores candidatos:", length(predictores_todos(d)), "\n")
