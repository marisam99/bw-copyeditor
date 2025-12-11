# ==============================================================================
# Title:        Get Logs
# Description:  Retrieves stored responses from OpenAI's Responses API and converts to dataframe.
# Output:       Dataframe for debugging, evaluations, and analysis
# ==============================================================================

source("config/dependencies.R")
library(httr2)
base_url <- "https://api.openai.com/v1/responses"
api_key <- Sys.getenv("OPENAI_API_KEY")

# Helper Function -------------------------------------------------------------
# Responses list endpoint is paginated
fetch_responses_page <- function(after = NULL, limit = 100) {
  req <- request(base_url) |>
    req_auth_bearer_token(api_key) |>
    req_url_query(limit = limit)

  if (!is.null(after)) {
    req <- req |> req_url_query(after = after)
  }

  resp <- req_perform(req)
  parsed <- resp_body_json(resp, simplifyVector = FALSE)

  parsed
}

# Main Function --------------------------------------------------------------


