# ==============================================================================
# Title:        Deployment Script for shinyapps.io
# Description:  Deploys BW Copyeditor to shinyapps.io with explicit file control.
#               Uses appFiles parameter to exclude unnecessary files.
# ==============================================================================

# Load required package
library(rsconnect)

# Files to include (excludes .Renviron, .claude/, tests/, etc.)
app_files <- c(
  "app.R",
  "app_instructions.md",
  ".Renviron",
  "config/",
  "helpers"
)

# Deploy to shinyapps.io

deployApp(
  appName = "bw-copyeditor",
  appFiles = app_files,
  account = "bellwether",
  server = "shinyapps.io",
  forceUpdate = TRUE,
  launch.browser = TRUE
)
