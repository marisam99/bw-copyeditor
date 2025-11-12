source("config/model_config.R")
source("R/parse_documents.R")
source("R/build_prompt_text.R")
source("R/build_prompt_images.R")
source("R/call_openai_api.R")
source("R/format_results.R")

edlight <- parse_document(mode = "text")
edlight_prompt <- build_prompt_text(edlight, "case study for publication", "funders, ed tech developers, and policymakers")
edlight_msg <- edlight_prompt$user_message[1]
edlight_rsp4 <- call_openai_api(edlight_msg)

cpr <- parse_document(mode = "text")
cpr_prompt <- build_prompt_text(cpr, "publication", "funders and policymakers")
cpr_msg <- cpr_prompt$user_message[1]
cpr_rsp <- call_openai_api(cpr_msg)
cpr_result <- format_results(cpr_rsp)
