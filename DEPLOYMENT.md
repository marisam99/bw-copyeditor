# Deploying BW Copyeditor to shinyapps.io

This guide walks you through deploying the BW Copyeditor Shiny app to shinyapps.io.

## Prerequisites

- ✅ Active shinyapps.io account (free or paid tier)
- ✅ R installed on your local machine (version 4.0.0 or higher)
- ✅ OpenAI API key (for the app to function)

## Step 1: Install rsconnect Package

Open R or RStudio and run:

```r
install.packages("rsconnect")
```

## Step 2: Get Your shinyapps.io Credentials

1. Log in to [shinyapps.io](https://www.shinyapps.io/)
2. Click your name in the top right → **Account**
3. Click **Tokens** in the left sidebar
4. Click **Show** next to your token, or click **Add Token** to create a new one
5. Copy the `setAccountInfo()` command that appears

It will look like this:
```r
rsconnect::setAccountInfo(
  name='your-account-name',
  token='your-token-here',
  secret='your-secret-here'
)
```

## Step 3: Configure rsconnect (One-time Setup)

Paste and run the `setAccountInfo()` command from Step 2 in your R console:

```r
rsconnect::setAccountInfo(
  name='your-account-name',
  token='your-token-here',
  secret='your-secret-here'
)
```

You should see a message confirming the account was registered.

## Step 4: Navigate to Project Directory

```r
# Set working directory to your bw-copyeditor project
setwd("/path/to/bw-copyeditor")

# Verify you're in the right place
list.files()  # Should show R/, inst/, config/, etc.
```

## Step 5: Deploy the App

**Important:** We deploy from the **project root**, not `inst/shiny-app/`, because the app needs access to:
- `R/` - Core function scripts
- `config/` - Configuration files
- `inst/shiny-app/` - The Shiny app itself

The `.rignore` file ensures development files (CLAUDE.md, TODO.md, tests/) are excluded.

```r
# Deploy from the project root
rsconnect::deployApp(
  appDir = ".",  # Current directory (project root)
  appPrimaryDoc = "inst/shiny-app/app.R",  # Tell rsconnect which file is the app
  appFiles = c(
    "inst/shiny-app/app.R",
    "inst/shiny-app/README.md",
    "R/",
    "config/"
  ),
  appName = "bw-copyeditor",  # Change this if you want a different URL
  launch.browser = TRUE
)
```

**What happens during deployment:**
- All app files (`app.R`, `README.md`) are uploaded
- R package dependencies are detected and installed on the server
- The app is built and started
- Your browser opens to the deployed app URL

**First deployment typically takes 5-10 minutes** as all packages are installed.

## Step 6: Configure Environment Variables

**CRITICAL:** The app won't work without your OpenAI API key.

1. Go to [shinyapps.io](https://www.shinyapps.io/)
2. Click **Applications** in the left sidebar
3. Click on **bw-copyeditor** (or whatever you named it)
4. Click the **Settings** tab
5. Scroll down to **Environment Variables**
6. Click **Add Variable**
7. Set:
   - **Name:** `OPENAI_API_KEY`
   - **Value:** Your OpenAI API key (starts with `sk-...`)
8. Click **Save Settings**
9. Click **Restart** to apply the changes

## Step 7: Test Your Deployed App

1. Visit your app URL: `https://your-account.shinyapps.io/bw-copyeditor`
2. Upload a small test PDF (< 5 pages recommended for first test)
3. Fill in document type and audience
4. Select processing mode (Text or Image)
5. Click "Process Document"
6. Verify results appear in the table

## Updating Your Deployed App

After making changes to your code, redeploy with:

```r
setwd("/path/to/bw-copyeditor")

rsconnect::deployApp(
  appDir = ".",
  appPrimaryDoc = "inst/shiny-app/app.R",
  appFiles = c(
    "inst/shiny-app/app.R",
    "inst/shiny-app/README.md",
    "R/",
    "config/"
  ),
  appName = "bw-copyeditor",
  launch.browser = FALSE
)
```

The app will be updated without creating a new instance.

## What Gets Deployed?

**Files included in deployment:**
- `inst/shiny-app/app.R` - The Shiny app
- `inst/shiny-app/README.md` - App instructions
- `R/` - All R function scripts (extract_documents.R, build_prompt_text.R, etc.)
- `config/` - Configuration files (dependencies.R, model_config.R)

**Files excluded (via .rignore):**
- `CLAUDE.md` - Development documentation
- `TODO.md` - Task tracking
- `tests/` - Test files
- `.git/` - Git repository data
- `.Rproj` files - RStudio project files

This ensures your deployed app only contains what it needs to run, keeping it clean and secure.

## Troubleshooting

### Deployment Fails with "Package X not found"

The deployment should auto-detect dependencies from your R scripts. If a package is missing:

1. Ensure the package is loaded in `config/dependencies.R`
2. Redeploy - rsconnect will detect all `library()` calls

### App Deploys But Shows Errors

**Check the logs:**
```r
rsconnect::showLogs(appName = "bw-copyeditor")
```

Common issues:
- **"OPENAI_API_KEY not found"**: Add the environment variable in shinyapps.io settings
- **"Cannot find file"**: Ensure all sourced files (R/, config/) are in `inst/shiny-app/` or use proper relative paths

### App Won't Start After Deployment

1. Check the logs: `rsconnect::showLogs(appName = "bw-copyeditor")`
2. Verify the `OPENAI_API_KEY` environment variable is set
3. Restart the app from the shinyapps.io dashboard

## Managing Your App

### View App Logs
```r
rsconnect::showLogs(appName = "bw-copyeditor")
```

### List Your Deployed Apps
```r
rsconnect::applications()
```

### Terminate (Delete) an App
From the shinyapps.io dashboard:
1. Go to **Applications**
2. Click on your app
3. Click **Settings**
4. Scroll to **Danger Zone**
5. Click **Archive Application**

## Security Best Practices

1. **Never commit API keys to git** - Always use environment variables
2. **Use environment variables** - Set `OPENAI_API_KEY` in shinyapps.io settings only
3. **Monitor usage** - Check your OpenAI API usage regularly
4. **Set usage limits** - Configure rate limits in your OpenAI account
5. **Consider authentication** - For sensitive documents, add user authentication (requires paid plan)

## Next Steps

- Share your app URL with colleagues: `https://your-account.shinyapps.io/bw-copyeditor`
- Monitor app usage in the shinyapps.io dashboard
- Set up email notifications for errors or downtime
- Consider upgrading if you need more active hours or features

## Questions or Issues?

- **shinyapps.io help**: [docs.posit.co/shinyapps.io](https://docs.posit.co/shinyapps.io/)
- **rsconnect documentation**: Run `?rsconnect::deployApp` in R
- **Check app logs**: `rsconnect::showLogs(appName = "bw-copyeditor")`
