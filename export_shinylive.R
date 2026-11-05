# Export the Shiny app to a static Shinylive (webR) site.
#
# Usage (from the project root):
#   Rscript --vanilla export_shinylive.R
#
# Only app.R and data/app_data.rds are bundled; everything else in the
# project (renv/, the Excel source, manifest.json, ...) is left out so the
# browser download stays small.

for (pkg in c("shinylive", "httpuv")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing '", pkg, "' package...")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

output_dir <- "docs" # GitHub Pages can serve from /docs on the main branch

# Rebuild the data file if it is missing
if (!file.exists("data/app_data.rds")) {
  message("data/app_data.rds not found, running process_data.R ...")
  source("process_data.R", encoding = "UTF-8")
}

# Stage a minimal copy of the app
stage_dir <- file.path(tempdir(), "rice_pest_app")
unlink(stage_dir, recursive = TRUE)
dir.create(file.path(stage_dir, "data"), recursive = TRUE)
file.copy("app.R", stage_dir)
file.copy("data/app_data.rds", file.path(stage_dir, "data"))

if (dir.exists(output_dir)) {
  message("Removing existing ", output_dir, " directory...")
  unlink(output_dir, recursive = TRUE)
}

message("Exporting Shinylive app to ", output_dir, " ...")
shinylive::export(stage_dir, output_dir)

# Tell GitHub Pages not to run Jekyll on the output
file.create(file.path(output_dir, ".nojekyll"))

message("Done. Preview with:")
message("  httpuv::runStaticServer('", output_dir, "')")
