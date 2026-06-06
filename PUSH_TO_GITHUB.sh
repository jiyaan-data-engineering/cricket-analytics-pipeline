#!/bin/bash
# Complete script to push cricket-analytics-pipeline to GitHub
# Run this script from the project root directory

set -e  # Exit on error

echo "=========================================="
echo "Cricket Analytics Pipeline - GitHub Setup"
echo "=========================================="
echo ""

# Step 1: Initialize Git
echo "Step 1: Initializing Git Repository..."
if [ -d ".git" ]; then
    echo "✓ Git repository already initialized"
else
    git init
    echo "✓ Git repository initialized"
fi

# Step 2: Configure Git
echo ""
echo "Step 2: Configuring Git..."
echo "Enter your name (for commits):"
read -p "Name: " GIT_NAME
echo "Enter your email (for commits):"
read -p "Email: " GIT_EMAIL

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
echo "✓ Git configured with name and email"

# Step 3: Add Remote
echo ""
echo "Step 3: Adding GitHub Remote..."
REPO_URL="https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git"

# Check if remote already exists
if git remote get-url origin &>/dev/null; then
    echo "Remote already exists. Current URL:"
    git remote get-url origin
    read -p "Update remote URL? (y/n): " UPDATE_REMOTE
    if [ "$UPDATE_REMOTE" = "y" ]; then
        git remote set-url origin "$REPO_URL"
        echo "✓ Remote URL updated"
    fi
else
    git remote add origin "$REPO_URL"
    echo "✓ Remote added: $REPO_URL"
fi

# Step 4: Verify Files
echo ""
echo "Step 4: Verifying Project Files..."
FILES=(
    "README.md"
    "LICENSE"
    "CONTRIBUTING.md"
    ".gitignore"
    "config/config.yaml"
    "ingestion/fetch_batting_rankings.py"
    "dataflow/pipeline.py"
    "terraform/main.tf"
    "bigquery/sql/01_create_raw_table.sql"
)

MISSING=0
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ $file (MISSING)"
        MISSING=$((MISSING+1))
    fi
done

if [ $MISSING -gt 0 ]; then
    echo ""
    echo "⚠ Warning: $MISSING files are missing"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# Step 5: Stage Files
echo ""
echo "Step 5: Staging Files..."
git add .
echo "✓ All files staged"

# Step 6: Show Status
echo ""
echo "Step 6: Current Git Status:"
git status

# Step 7: Commit
echo ""
echo "Step 7: Creating Commit..."
echo "Existing commits:"
git log --oneline -5 2>/dev/null || echo "(No commits yet)"
echo ""
read -p "Commit all changes? (y/n): " COMMIT_CONFIRMED
if [ "$COMMIT_CONFIRMED" != "y" ]; then
    echo "Aborted."
    exit 1
fi

git commit -m "Initial commit: Cricket Analytics Pipeline

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
License: Apache 2.0"

echo "✓ Commit created"

# Step 8: Create/Verify Master Branch
echo ""
echo "Step 8: Setting Up Master Branch..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "Renaming branch to master..."
    git branch -M master
    echo "✓ Branch renamed to master"
else
    echo "✓ Already on master branch"
fi

# Step 9: Push to GitHub
echo ""
echo "Step 9: Pushing to GitHub..."
echo "Repository: https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline"
echo ""
read -p "Push to GitHub? (y/n): " PUSH_CONFIRMED
if [ "$PUSH_CONFIRMED" != "y" ]; then
    echo "Aborted. Your changes are committed locally but not pushed."
    echo "To push later, run: git push -u origin master"
    exit 0
fi

git push -u origin master
echo "✓ Code pushed to master branch"

# Step 10: Verify
echo ""
echo "Step 10: Verifying Remote..."
git remote -v
echo "✓ Remote verified"

# Step 11: Show Log
echo ""
echo "Step 11: Commit History:"
git log --oneline -3

# Success
echo ""
echo "=========================================="
echo "✓ SUCCESS!"
echo "=========================================="
echo ""
echo "Your repository is now on GitHub:"
echo "https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline"
echo ""
echo "Next steps:"
echo "1. Visit the GitHub repository"
echo "2. Add topics (data-engineering, gcp, bigquery, etc.)"
echo "3. Enable GitHub Discussions"
echo "4. Create issue/PR templates"
echo "5. Share with your team!"
echo ""
echo "To continue working locally:"
echo "  git checkout master"
echo "  git pull origin master"
echo ""
echo "To create a new branch for features:"
echo "  git checkout -b feature/your-feature-name"
echo "  git add ."
echo "  git commit -m 'description'"
echo "  git push -u origin feature/your-feature-name"
echo ""
