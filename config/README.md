# Configuration Files

This directory contains templates and configuration files for the bw-copyeditor tool.

## Files

### `system_prompt_template.txt`

Template for the system prompt that includes your organization's style guide.

**Usage:**
1. Copy this file to `system_prompt.txt` (or any name you prefer)
2. Edit the style guide section to match your organization's conventions
3. Load it in your R script:

```r
system_prompt <- load_system_prompt("config/system_prompt.txt")

results <- process_document(
  file_path = "document.pdf",
  system_prompt = system_prompt
)
```

**What to customize:**
- General conventions (voice, tone, language preferences)
- Organization-specific terminology
- Number and date formatting rules
- Punctuation preferences
- Citation and reference styles
- Severity guidelines (what counts as critical vs. optional)

### `project_context_template.txt`

Template for providing project-specific context to the copyeditor.

**Usage:**
1. For each project, fill out the relevant sections of this template
2. Pass the completed text as the `project_context` parameter:

```r
project_context <- "
PROJECT INFORMATION:
Project Name: Q4 2024 Report
Client: ABC Corp
...
"

results <- process_document(
  file_path = "document.pdf",
  project_context = project_context
)
```

**What to include:**
- Project and client information
- Document type and target audience
- Subject matter and key terminology
- Tone and style preferences
- Any project-specific considerations

## Tips

1. **Keep system prompts stable**: Create one system prompt per organization or document type, and reuse it consistently. This ensures consistent copyediting standards.

2. **Update project context frequently**: The project context should be tailored for each specific document or client engagement.

3. **Version control**: Track changes to your system prompts so you can understand how your copyediting standards evolve over time.

4. **Test iteratively**: Start with a simple system prompt and gradually add more specific rules based on the types of issues you encounter.

5. **Token limits**: Very long system prompts increase API costs. Keep prompts focused on the most important rules.

## Example Organization

You might organize your configuration files like this:

```
config/
├── system_prompts/
│   ├── bellwether_general.txt       # General organizational style
│   ├── bellwether_technical.txt     # For technical reports
│   ├── bellwether_executive.txt     # For executive summaries
│   └── client_specific/
│       ├── client_a.txt             # Client-specific style
│       └── client_b.txt
├── project_contexts/
│   ├── 2024_q1_report.txt
│   ├── 2024_q2_report.txt
│   └── templates/
│       ├── quarterly_report.txt
│       └── technical_memo.txt
└── README.md
```

Then in your R scripts:

```r
# Load appropriate system prompt
system_prompt <- load_system_prompt("config/system_prompts/bellwether_technical.txt")

# Load project context
project_context_file <- "config/project_contexts/2024_q1_report.txt"
project_context <- paste(readLines(project_context_file), collapse = "\n")

# Process document
results <- process_document(
  file_path = "report.pdf",
  system_prompt = system_prompt,
  project_context = project_context
)
```
