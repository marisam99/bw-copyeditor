# ==============================================================================
# Title:        User Tests Round 1
# Description:  Code I've been using repeatedly to test the different scripts
# ==============================================================================

source("R/bw_copyeditor.R")

# Test No. 1: Text-Mode, shorter document (6 pages)
# EdLight Case Study:

copyedit_document(mode = "text", document_type = "case study for publication", audience = "funders, ed tech developers, and policymakers")

# Test No. 2: Text-Mode, longer document (19 pages)
# The Pandemic Project report

copyedit_document(mode = "text", document_type = "case study for publication", audience = "funders, ed tech developers, and policymakers")

# Test No. 3: Image Mode, shorter document (37 pages)
# CMO survey

copyedit_document(mode = "images", document_type = "draft of survey questions", audience = "charter management organization leaders")

# Test No. 4: Image Mode, longer document (100 pages)
# Community College Funding Formula Landscape Scan 

copyedit_document(mode = "images", document_type = "landscape scan research presentation", audience = "clients who are philanthropic funders")