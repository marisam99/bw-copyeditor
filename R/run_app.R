# ==============================================================================
# Title:        Shiny App Launcher
# Last Updated: 2025-01-17
# Description:  Helper function to launch the BW Copyeditor Shiny app
# ==============================================================================

#' Launch BW Copyeditor Shiny App
#'
#' Opens the interactive web interface for copyediting documents.
#' This provides a user-friendly GUI alternative to the command-line interface.
#'
#' @return Opens the Shiny app in your default web browser
#'
#' @examples
#' \dontrun{
#'   # Launch the app
#'   run_copyeditor_app()
#' }
#'
#' @export
run_copyeditor_app <- function() {
  app_dir <- system.file("shiny-app", package = "bwcopyeditor")

  if (app_dir == "" || !dir.exists(app_dir)) {
    stop(
      "Could not find Shiny app directory. ",
      "Please ensure the package is properly installed with: ",
      "devtools::install()"
    )
  }

  message("Starting BW Copyeditor Shiny app...")
  message("The app will open in your web browser.\n")

  shiny::runApp(app_dir, display.mode = "normal", launch.browser = TRUE)
}
