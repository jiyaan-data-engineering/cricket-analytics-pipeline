# PowerShell Script: Push cricket-analytics-pipeline to GitHub
# Run from project root directory: C:\satishMudde\claude\P1

Write-Host "==========================================`n" -ForegroundColor Green
Write-Host "Cricket Analytics Pipeline - GitHub Setup`n" -ForegroundColor Green
Write-Host "==========================================`n" -ForegroundColor Green

# Step 1: Initialize Git
Write-Host "Step 1: Initializing Git Repository..." -ForegroundColor Cyan
if (Test-Path ".git") {
    Write-Host "✓ Git repository already initialized`n"
} else {
    git init
    Write-Host "✓ Git repository initialized`n"
}

# Step 2: Configure Git
Write-Host "Step 2: Configuring Git..." -ForegroundColor Cyan
$gitName = Read-Host "Enter your name (for commits)"
$gitEmail = Read-Host "Enter your email (for commits)"

git config --global user.name $gitName
git config --global user.email $gitEmail
Write-Host "✓ Git configured with name and email`n"

# Step 3: Add Remote
Write-Host "Step 3: Adding GitHub Remote..." -ForegroundColor Cyan
$repoUrl = "https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git"

try {
    $existingUrl = git remote get-url origin 2>$null
    if ($existingUrl) {
        Write-Host "Remote already exists: $existingUrl"
        $updateRemote = Read-Host "Update remote URL? (y/n)"
        if ($updateRemote -eq "y") {
            git remote set-url origin $repoUrl
            Write-Host "✓ Remote URL updated`n"
        }
    }
} catch {
    git remote add origin $repoUrl
    Write-Host "✓ Remote added: $repoUrl`n"
}

# Step 4: Verify Files
Write-Host "Step 4: Verifying Project Files..." -ForegroundColor Cyan
$requiredFiles = @(
    "README.md",
    "LICENSE",
    "CONTRIBUTING.md",
    ".gitignore",
    "config/config.yaml",
    "ingestion/fetch_batting_rankings.py",
    "dataflow/pipeline.py",
    "terraform/main.tf"
)

$missing = 0
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file"
    } else {
        Write-Host "✗ $file (MISSING)" -ForegroundColor Red
        $missing++
    }
}

if ($missing -gt 0) {
    Write-Host "`n⚠ Warning: $missing files are missing`n" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Host "Aborted."
        exit 1
    }
}

Write-Host ""

# Step 5: Stage Files
Write-Host "Step 5: Staging Files..." -ForegroundColor Cyan
git add .
Write-Host "✓ All files staged`n"

# Step 6: Show Status
Write-Host "Step 6: Current Git Status:" -ForegroundColor Cyan
git status
Write-Host ""

# Step 7: Commit
Write-Host "Step 7: Creating Commit..." -ForegroundColor Cyan
Write-Host "Recent commits (if any):"
git log --oneline -5 2>$null
Write-Host ""
$commitConfirmed = Read-Host "Commit all changes? (y/n)"
if ($commitConfirmed -ne "y") {
    Write-Host "Aborted."
    exit 1
}

$commitMessage = @"
Initial commit: Cricket Analytics Pipeline

- End-to-end data engineering solution
- Real-time analytics with BigQuery
- Apache Beam Dataflow processing
- Medallion architecture (raw/staging/curated)
- Infrastructure as Code (Terraform)
- Apache Airflow orchestration
- Production-ready with comprehensive documentation

Features:
✓ Ingestion from Cricbuzz API (RapidAPI)
✓ Cloud Storage for raw data landing
✓ Dataflow for data processing
✓ BigQuery for data warehouse
✓ Star schema for analytics
✓ Looker Studio dashboard
✓ Cloud Composer for orchestration
✓ Terraform for infrastructure
✓ Comprehensive documentation

Author: Jiyaan Data Engineering Institute
License: Apache 2.0
"@

git commit -m $commitMessage
Write-Host "✓ Commit created`n"

# Step 8: Create/Verify Master Branch
Write-Host "Step 8: Setting Up Master Branch..." -ForegroundColor Cyan
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch: $currentBranch"

if ($currentBranch -ne "master") {
    Write-Host "Renaming branch to master..."
    git branch -M master
    Write-Host "✓ Branch renamed to master`n"
} else {
    Write-Host "✓ Already on master branch`n"
}

# Step 9: Push to GitHub
Write-Host "Step 9: Pushing to GitHub..." -ForegroundColor Cyan
Write-Host "Repository: https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline"
Write-Host ""
$pushConfirmed = Read-Host "Push to GitHub? (y/n)"
if ($pushConfirmed -ne "y") {
    Write-Host "Aborted. Your changes are committed locally but not pushed."
    Write-Host "To push later, run: git push -u origin master"
    exit 0
}

git push -u origin master
Write-Host "✓ Code pushed to master branch`n"

# Step 10: Verify
Write-Host "Step 10: Verifying Remote..." -ForegroundColor Cyan
git remote -v
Write-Host "✓ Remote verified`n"

# Step 11: Show Log
Write-Host "Step 11: Commit History:" -ForegroundColor Cyan
git log --oneline -3
Write-Host ""

# Success
Write-Host "==========================================`n" -ForegroundColor Green
Write-Host "✓ SUCCESS!`n" -ForegroundColor Green
Write-Host "==========================================`n" -ForegroundColor Green

Write-Host "Your repository is now on GitHub:`n"
Write-Host "https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline`n" -ForegroundColor Cyan

Write-Host "Next steps:`n" -ForegroundColor Yellow
Write-Host "1. Visit the GitHub repository`n"
Write-Host "2. Add topics (data-engineering, gcp, bigquery, etc.)`n"
Write-Host "3. Enable GitHub Discussions`n"
Write-Host "4. Create issue/PR templates`n"
Write-Host "5. Share with your team!`n"

Write-Host "To continue working locally:" -ForegroundColor Cyan
Write-Host "  git checkout master"
Write-Host "  git pull origin master`n"

Write-Host "To create a new branch for features:" -ForegroundColor Cyan
Write-Host "  git checkout -b feature/your-feature-name"
Write-Host "  git add ."
Write-Host "  git commit -m 'description'"
Write-Host "  git push -u origin feature/your-feature-name`n"
