# 🔐 SECURE GCP SETUP SCRIPT (Windows PowerShell)
# Usage: .\SETUP_GCP_SECURE.ps1

Write-Host "🔐 Cricket Analytics Pipeline - Secure GCP Setup (Windows)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get credentials
Write-Host "📝 Step 1: Enter GCP Credentials" -ForegroundColor Yellow
Write-Host "(DO NOT use your actual Google password!)" -ForegroundColor Red
Write-Host "(Instead, create a Service Account with JSON key)" -ForegroundColor Yellow
Write-Host ""

$GCP_PROJECT_ID = Read-Host "Enter your GCP Project ID (e.g., my-project-123)"
$RAPIDAPI_KEY = Read-Host "Enter your RAPIDAPI Key" -AsSecureString
$RAPIDAPI_KEY_PLAIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($RAPIDAPI_KEY))

# Validate
if ([string]::IsNullOrWhiteSpace($GCP_PROJECT_ID)) {
    Write-Host "❌ Error: Project ID cannot be empty" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Project ID: $GCP_PROJECT_ID" -ForegroundColor Green
Write-Host ""

# Step 2: Update config
Write-Host "🔧 Step 2: Updating configuration..." -ForegroundColor Yellow
$CONFIG_FILE = "pipeline/config/config.yaml"

if (Test-Path $CONFIG_FILE) {
    # Create backup
    Copy-Item $CONFIG_FILE "$CONFIG_FILE.backup"
    Write-Host "✅ Backup created: $CONFIG_FILE.backup" -ForegroundColor Green

    # Read and update
    $content = Get-Content $CONFIG_FILE
    $content = $content -replace 'project_id: .*', "project_id: `"$GCP_PROJECT_ID`""
    $content | Set-Content $CONFIG_FILE

    Write-Host "✅ Updated project_id in config.yaml" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: config.yaml not found at $CONFIG_FILE" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Set environment variables
Write-Host "🌍 Step 3: Setting environment variables..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Run these commands to set environment variables:" -ForegroundColor Cyan
Write-Host "`$env:GCP_PROJECT_ID = '$GCP_PROJECT_ID'" -ForegroundColor Gray
Write-Host "`$env:RAPIDAPI_KEY = 'your-rapidapi-key-here'" -ForegroundColor Gray
Write-Host ""

# Step 4: Set environment variables for current session
$env:GCP_PROJECT_ID = $GCP_PROJECT_ID
$env:RAPIDAPI_KEY = $RAPIDAPI_KEY_PLAIN

Write-Host "✅ Environment variables set for current session" -ForegroundColor Green
Write-Host ""

# Step 5: gcloud setup
Write-Host "☁️  Step 4: Setting up gcloud CLI..." -ForegroundColor Yellow
Write-Host "Opening Google login in browser..." -ForegroundColor Cyan
gcloud auth login
gcloud config set project $GCP_PROJECT_ID
Write-Host "✅ gcloud CLI configured" -ForegroundColor Green
Write-Host ""

# Step 6: Create .env.local file
Write-Host "📄 Step 5: Creating .env.local file..." -ForegroundColor Yellow
$env_content = @"
# Local Environment Variables
# DO NOT COMMIT THIS FILE!
GCP_PROJECT_ID=$GCP_PROJECT_ID
RAPIDAPI_KEY=$RAPIDAPI_KEY_PLAIN
"@

$env_content | Set-Content ".env.local"
Write-Host "✅ .env.local created" -ForegroundColor Green
Write-Host "⚠️  Remember: Add .env.local to .gitignore!" -ForegroundColor Yellow
Write-Host ""

# Step 7: Verify setup
Write-Host "🔍 Step 6: Verifying setup..." -ForegroundColor Yellow
gcloud config list
Write-Host ""

Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📚 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Read Documentation/README.md" -ForegroundColor Gray
Write-Host "2. Review Documentation/GCP_PROJECT.md" -ForegroundColor Gray
Write-Host "3. Deploy infrastructure: cd infrastructure/terraform && terraform init && terraform apply" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  SECURITY REMINDERS:" -ForegroundColor Red
Write-Host "- Never commit .env.local or config.yaml with actual values" -ForegroundColor Yellow
Write-Host "- Use environment variables for sensitive data" -ForegroundColor Yellow
Write-Host "- Create Service Accounts instead of using personal credentials" -ForegroundColor Yellow
Write-Host "- Use GitHub Secrets for CI/CD pipelines" -ForegroundColor Yellow
Write-Host "- Rotate keys regularly" -ForegroundColor Yellow
Write-Host ""
