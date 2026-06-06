#!/bin/bash

# 🔐 SECURE GCP SETUP SCRIPT
# Usage: bash SETUP_GCP_SECURE.sh

set -e

echo "🔐 Cricket Analytics Pipeline - Secure GCP Setup"
echo "=================================================="
echo ""

# Step 1: Get credentials
echo "📝 Step 1: Enter GCP Credentials"
echo "(You'll paste the JSON credentials file, not password!)"
echo ""
read -p "Enter your GCP Project ID (e.g., my-project-123): " GCP_PROJECT_ID
read -sp "Enter your RAPIDAPI Key (hidden): " RAPIDAPI_KEY
echo ""
echo ""

# Step 2: Validate project ID
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ Error: Project ID cannot be empty"
    exit 1
fi

echo "✅ Project ID: $GCP_PROJECT_ID"
echo ""

# Step 3: Update config
echo "🔧 Step 2: Updating configuration..."
CONFIG_FILE="pipeline/config/config.yaml"

if [ -f "$CONFIG_FILE" ]; then
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    echo "✅ Backup created: $CONFIG_FILE.backup"

    # Update project ID (use actual value, not placeholder)
    sed -i "s/project_id: .*/project_id: \"$GCP_PROJECT_ID\"/" "$CONFIG_FILE"
    echo "✅ Updated project_id in config.yaml"
else
    echo "⚠️  Warning: config.yaml not found at $CONFIG_FILE"
fi

# Step 4: Set environment variables
echo ""
echo "🌍 Step 3: Setting environment variables..."
echo ""
echo "Add these to your shell profile (~/.bashrc, ~/.zshrc, or .env):"
echo ""
echo "export GCP_PROJECT_ID=\"$GCP_PROJECT_ID\""
echo "export RAPIDAPI_KEY=\"\$RAPIDAPI_KEY\""  # Don't expand in display
echo ""

# Step 5: gcloud setup
echo "☁️  Step 4: Setting up gcloud CLI..."
gcloud auth login
gcloud config set project "$GCP_PROJECT_ID"
echo "✅ gcloud CLI configured"
echo ""

# Step 6: Create .env file
echo "📄 Step 5: Creating .env file for local development..."
cat > .env.local << EOF
# Local Environment Variables
# DO NOT COMMIT THIS FILE!
GCP_PROJECT_ID=$GCP_PROJECT_ID
RAPIDAPI_KEY=$RAPIDAPI_KEY
EOF
echo "✅ .env.local created"
echo "⚠️  Remember: Add .env.local to .gitignore!"
echo ""

# Step 7: Verify setup
echo "🔍 Step 6: Verifying setup..."
gcloud config list
echo ""

echo "✅ Setup Complete!"
echo ""
echo "📚 Next Steps:"
echo "1. Read Documentation/README.md"
echo "2. Review Documentation/GCP_PROJECT.md"
echo "3. Deploy infrastructure: cd infrastructure/terraform && terraform init && terraform apply"
echo ""
echo "⚠️  SECURITY REMINDERS:"
echo "- Never commit .env.local, credentials.json, or config.yaml with actual values"
echo "- Use environment variables for sensitive data"
echo "- Use GitHub Secrets for CI/CD pipelines"
echo "- Rotate keys regularly"
echo ""
