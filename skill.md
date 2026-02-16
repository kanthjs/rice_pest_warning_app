---
name: Shinylive Export
description: Instructions for converting the R Shiny app to a static Shinylive app.
---

# Shinylive Conversion Guide

This guide details how to convert the existing R Shiny application into a Shinylive application, allowing it to run entirely in the browser without a backend R server.

## Prerequisites

Ensure you have the following R packages installed:

- `shinylive`: For exporting the app.
- `httpuv`: For serving the app locally to test.

You can install them via the R console:

```r
install.packages("shinylive")
install.packages("httpuv")
```

## Exporting the App

We have provided a helper script `export_shinylive.R` to automate the export process. This script creates a `site/` directory containing the static web assets.

To run the export script, we recommend using the provided PowerShell script which automatically detects the latest R version:

```powershell
.\build_shinylive.ps1
```

If you prefer to run it manually (and have a modern R version in your PATH):

```bash
Rscript export_shinylive.R
```

Alternatively, you can run it from within an R session:

```r
source("export_shinylive.R")
```

## Previewing Locally

After exporting, the static application is located in the `site/` folder. To verify that it works correctly, you can serve it locally using `httpuv`.

Run this in your R console:

```r
httpuv::runStaticServer("site")
```

This will start a local web server and open the app in your browser.

## Deployment to GitHub Pages

The `site/` folder is configured to be easily deployable to GitHub Pages.

1. Push your changes (including the `site/` folder) to GitHub.
2. Go to your repository on GitHub.
3. Navigate to **Settings** > **Pages**.
4. Under **Build and deployment** > **Source**, select **Deploy from a branch**.
5. Under **Branch**, select `main` (or your current branch) and choose the `/site` folder.
6. Click **Save**.

Your app will be live at the provided URL shortly.
