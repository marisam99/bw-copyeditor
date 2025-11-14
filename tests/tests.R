# STEP BY STEP TESTING FOR DEBUGGING: ---------------------------------------
source("config/dependencies.R")
source("config/model_config.R")
source("R/load_context.R")
source("R/extract_documents.R")
source("R/build_prompt_text.R")
source("R/build_prompt_images.R")
source("R/call_openai_api.R")
source("R/process_results.R")

## TEXT MODE
edlight <- extract_document(mode = "text")
edlight_prompt <- build_prompt_text(edlight, "case study for publication", "funders, ed tech developers, and policymakers")
edlight_msg <- edlight_prompt$user_message[1]
edlight_rsp <- call_openai_api_text(edlight_msg)
edlight_edits <- format_results(edlight_rsp$suggestions)

cpr <- extract_document(mode = "text")
cpr_prompt <- build_prompt_text(cpr, "publication", "funders and policymakers")
cpr_msg <- cpr_prompt$user_message[1]
cpr_rsp <- call_openai_api_text(cpr_msg)
cpr_result <- format_results(cpr_rsp)

## IMAGE MODE
skunkworks301 <- extract_document(mode = "images")
skunk_prompt <- build_prompt_images(skunkworks301, 
  "internal presentation", "non-technical colleagues")
skunk_msg <- skunk_prompt$user_message[[1]]
skunk_rsp <- call_openai_api_images(skunk_msg)
skunk_edits <- format_results(skunk_rsp$suggestions)

# FULL COPYEDITOR TESTING ------------------------------------------------------
source("R/bw_copyeditor.R")

copyedit_document(mode = "text", "publication", "funders and policymakers")
copyedit_document(mode = "images", "presentation", "nontechnical colleagues")
copyedit_document(mode = "images", "client-facing landscape scan", "funder clients")
