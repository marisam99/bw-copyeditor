source("config/model_config.R")
source("R/load_context.R")
source("R/extract_documents.R")
source("R/build_prompt_text.R")
source("R/build_prompt_images.R")
source("R/call_openai_api.R")
source("R/process_results.R")

# STEP BY STEP TESTING FOR DEBUGGING: TEXT MODE
edlight <- parse_document(mode = "text")
edlight_prompt <- build_prompt_text(edlight, "case study for publication", "funders, ed tech developers, and policymakers")
edlight_msg <- edlight_prompt$user_message[1]
edlight_rsp <- call_openai_api(edlight_msg)
edlight_edits <- format_results(edlight_rsp$suggestions)

cpr <- parse_document(mode = "text")
cpr_prompt <- build_prompt_text(cpr, "publication", "funders and policymakers")
cpr_msg <- cpr_prompt$user_message[1]
cpr_rsp <- call_openai_api(cpr_msg)
cpr_result <- format_results(cpr_rsp)

# STEP BY STEP TESTING FOR DEBUGGING: IMAGE MODE
skunkworks301 <- parse_document(mode = "images")
skunk_prompt <- build_prompt_images(skunkworks301, 
  "internal presentation", "non-technical colleagues")
skunk_msg <- skunk_prompt$user_message[[1]]
skunk_rsp <- call_openai_api_images(skunk_msg)
skunk_edits <- format_results(skunk_rsp$suggestions)

# FULL COPYEDITOR TESTING
copyedit_document(mode = "text", "publication", "funders and policymakers")
copyedit_document(mode = "images", "presentation", "nontechnical colleagues")