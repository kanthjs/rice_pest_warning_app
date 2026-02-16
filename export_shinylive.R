# Script to export Shiny app to Shinylive

# Check for required packages and install if missing
if (!requireNamespace("shinylive", quietly = TRUE)) {
    message("Installing 'shinylive' package...")
    install.packages("shinylive", repos = "https://cloud.r-project.org")
}
if (!requireNamespace("httpuv", quietly = TRUE)) {
    message("Installing 'httpuv' package...")
    install.packages("httpuv", repos = "https://cloud.r-project.org")
}

# Define input and output directories
app_dir <- "."
output_dir <- "site"

# Clean output directory if it exists to avoid conflicts
if (dir.exists(output_dir)) {
    message(paste("Removing existing", output_dir, "directory..."))
    unlink(output_dir, recursive = TRUE)
}

# Export the application
message(paste("Exporting Shinylive app from", app_dir, "to", output_dir, "..."))
tryCatch(
    {
        shinylive::export(app_dir, output_dir)
        message("Export successfully completed!")
        message("To preview the app, run the following command in R:")
        message(paste0("httpuv::runStaticServer('", output_dir, "')"))
    },
    error = function(e) {
        message("Error during export:")
        message(e$message)
    }
)
