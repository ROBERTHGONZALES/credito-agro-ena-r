# 17 · Exporta el dashboard con Shinylive (Shiny en el navegador, sin servidor) a docs/ para publicarlo en GitHub Pages.
#   Antes: Rscript R/15_exportar_csv.R y Rscript R/16_dashboard_departamentos.R (generan R/dashboard/datos).
#   Uso (desde la raíz del repositorio):  Rscript R/17_publicar_dashboard.R
#   Prueba local:  Rscript -e "httpuv::runStaticServer('docs', port = 8053)"  y abrir http://localhost:8053
#   GitHub Pages sirve la carpeta docs/ de la rama main.
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "_comun.R"))
destino <- file.path(RAIZ, "docs")
if (dir.exists(destino)) unlink(destino, recursive = TRUE)
shinylive::export(appdir = file.path(BASE, "dashboard"), destdir = destino, title = "Crédito agrario en el Perú · ENA 2016–2025")
file.create(file.path(destino, ".nojekyll"))   # GitHub Pages no debe procesar los archivos con Jekyll
cat("ok: dashboard exportado en", destino, "\n")
