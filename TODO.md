# TODO

## Pre-Deployment Tasks
- [x] Local testing completed
- [ ] Customize README in `inst/shiny-app/README.md` for end users
  - Remove developer-focused sections (local setup, package installation, troubleshooting)
  - Add team-specific examples for document type and audience
  - Add any BW style guidelines or preferences
  - Keep it simple and focused on *using* the app

## Deployment to shinyapps.io
- [ ] Create shinyapps.io account (free tier available)
- [ ] Install rsconnect package: `install.packages("rsconnect")`
- [ ] Get token/secret from shinyapps.io dashboard
- [ ] Set up authentication in R:
  ```r
  rsconnect::setAccountInfo(
    name = "your-account",
    token = "your-token",
    secret = "your-secret"
  )
  ```
- [ ] Deploy the app:
  ```r
  setwd("inst/shiny-app")
  rsconnect::deployApp()
  ```
- [ ] Set `OPENAI_API_KEY` as environment variable in shinyapps.io dashboard
  - Go to app settings → Variables
  - Add: `OPENAI_API_KEY = your-key-here`
- [ ] Test the deployed app yourself before sharing

## User Testing
- [ ] Share app URL with 2-3 trusted colleagues first
- [ ] Brief them on:
  - What the app does (flags copyediting errors for review)
  - What to test (their real documents)
  - How to give feedback
- [ ] Collect feedback
- [ ] Address any issues found
- [ ] Share more widely if working well

## Future Enhancements
- [ ] (Add ideas from user feedback here)

---

**Notes:**
- Restart the Shiny app after editing the README to see changes
- Free tier shinyapps.io: 25 active hours/month, 5 apps
- This file is tracked in git - add to `.gitignore` if you want it private
