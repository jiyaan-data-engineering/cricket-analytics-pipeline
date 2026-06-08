# 🔐 Secure Credentials Management Guide

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Critical - Security

⚠️ **NEVER share passwords, API keys, or credentials in code, chat, or messages!**

---

## 🚨 CRITICAL: If Credentials Are Exposed

If you've shared credentials online (chat, GitHub, email):

**IMMEDIATELY DO THIS:**
```bash
# 1. Change your Google account password
# Go to: https://myaccount.google.com/security
# Click "Password" → Change it now

# 2. Change email password
# Go to: https://myaccount.google.com

# 3. Review GCP activity for unauthorized access
# Go to: https://console.cloud.google.com
# Check Audit Logs for suspicious activity

# 4. Rotate API keys and service account keys
# Delete old keys and create new ones
```

---

## ✅ CORRECT Ways to Use GCP Credentials

### **Option 1: Service Account Key (RECOMMENDED)**

**Why Service Accounts?**
- ✅ Separate identity from personal account
- ✅ Limited permissions (principle of least privilege)
- ✅ Can be rotated without affecting personal account
- ✅ Ideal for applications & CI/CD

**Setup Steps:**

```bash
# 1. Create Service Account in GCP Console
# Go to: IAM & Admin → Service Accounts
# Click: "Create Service Account"
# Name: cricket-pipeline-sa
# Description: Service account for Cricket Analytics Pipeline

# 2. Grant Roles
# Click on service account → IAM Roles
# Grant:
#   - BigQuery Admin
#   - Storage Admin
#   - Dataflow Admin
#   - Cloud Functions Developer
#   - Cloud Composer Worker

# 3. Create JSON Key
# Click on service account → Keys tab
# Click: "Add Key" → Create new key → JSON
# SAVE the file as: ~/.gcp/cricket-sa-key.json

# 4. Set environment variable (LOCAL DEVELOPMENT)
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/cricket-sa-key.json"

# 5. Verify it works
gcloud auth application-default login
gcloud config list
```

---

### **Option 2: Environment Variables (for Local Development)**

**Create `.env.local` file (NEVER commit this!):**

```bash
# .env.local (in root of project)
GCP_PROJECT_ID="your-gcp-project-id"
GCP_REGION="us-central1"
RAPIDAPI_KEY="your-rapidapi-key"
GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

**Set variables (Linux/Mac):**

```bash
# Add to ~/.bashrc or ~/.zshrc
export GCP_PROJECT_ID="your-project-id"
export RAPIDAPI_KEY="your-api-key"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/cricket-sa-key.json"

# Load in current session
source ~/.bashrc
```

**Set variables (Windows PowerShell):**

```powershell
# Set for current session
$env:GCP_PROJECT_ID = "your-project-id"
$env:RAPIDAPI_KEY = "your-api-key"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account-key.json"

# Set permanently (add to PowerShell profile)
# Open: $PROFILE
# Add the above lines
```

---

### **Option 3: Secure Setup Script**

**Linux/Mac:**
```bash
bash SETUP_GCP_SECURE.sh
```

**Windows PowerShell:**
```powershell
.\SETUP_GCP_SECURE.ps1
```

These scripts will:
1. Ask for credentials interactively (safe)
2. Update configuration files
3. Set environment variables
4. Create backups
5. Verify setup

---

## 🔒 Security Best Practices

### **1. NEVER Hardcode Credentials**

❌ **WRONG:**
```python
api_key = "68711780e9msh5801f4e4a2e884fp161186jsnbe9a5031365d"  # EXPOSED!
project_id = "my-gcp-project"
password = "SecretPassword123"
```

✅ **CORRECT:**
```python
import os
api_key = os.getenv("RAPIDAPI_KEY")      # From environment
project_id = os.getenv("GCP_PROJECT_ID")
# Don't store passwords - use keys instead
```

---

### **2. Use .gitignore for Sensitive Files**

```bash
# .gitignore
.env
.env.local
.env.*.local
*.json  # Service account keys
config.yaml  # If contains values
credentials.json
terraform.tfvars  # Terraform variables with values
```

**Verify nothing is committed:**
```bash
git status
git log --all --full-history -- "*.json"  # Check if accidentally committed
```

---

### **3. Different Credentials for Different Environments**

```
Development:
  - Use service account key locally
  - Set via GOOGLE_APPLICATION_CREDENTIALS env var
  - Use .env.local file

Testing:
  - Use separate test service account
  - Limited permissions
  - Isolated test project

Production:
  - Use separate production service account
  - Minimal permissions (read-only where possible)
  - Use Secret Manager or Vault
  - Audit all access
```

---

### **4. GitHub Secrets for CI/CD**

**For GitHub Actions workflows:**

1. Go to: Settings → Secrets and variables → Actions
2. Add secrets:
   - `GCP_PROJECT_ID` = your-project-id
   - `RAPIDAPI_KEY` = your-api-key

**Use in workflow:**
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v1
  with:
    workload_identity_provider: "projects/185087551442/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"
    service_account_email: "github-actions-deployer@cricbuzz-satish-dev.iam.gserviceaccount.com"

- name: Run tests
  env:
    GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
    RAPIDAPI_KEY: ${{ secrets.RAPIDAPI_KEY }}
  run: python tests/test_pipeline.py
```

---

### **5. Secret Manager for Production**

**For cloud deployments, use Google Secret Manager:**

```bash
# Create secret
echo -n "your-secret-value" | gcloud secrets create my-secret --data-file=-

# Use in Cloud Function
from google.cloud import secretmanager

def access_secret():
    client = secretmanager.SecretManagerServiceClient()
    secret_version = client.access_secret_version(
        request={"name": "projects/PROJECT_ID/secrets/my-secret/versions/latest"}
    )
    return secret_version.payload.data.decode("UTF-8")
```

---

## 📋 Security Checklist

- [ ] **Never shared credentials online** (chat, email, GitHub)
- [ ] **Using Service Accounts** (not personal credentials)
- [ ] **Credentials in environment variables** (not in code)
- [ ] **Sensitive files in .gitignore** (.env, *.json, terraform.tfvars)
- [ ] **.git/info/exclude** includes sensitive patterns
- [ ] **Using HTTPS** (not HTTP) for all connections
- [ ] **API keys rotated regularly** (every 90 days)
- [ ] **Audit logs enabled** (Cloud Audit Logs)
- [ ] **Least privilege principle** (minimal IAM roles)
- [ ] **GitHub Secrets configured** (for CI/CD)
- [ ] **Production using Secret Manager** (not env vars)
- [ ] **Credentials not in version history** (git history clean)

---

## 🔄 Key Rotation Procedure

**Every 90 days:**

```bash
# 1. Create new key
# Go to GCP Console → Service Accounts → Select account → Keys
# Click "Add Key" → Create JSON key

# 2. Update deployment
# Download new key
# Update GOOGLE_APPLICATION_CREDENTIALS env var
# Update GitHub Secrets
# Update cloud deployments

# 3. Delete old key
# Wait 24 hours to ensure no issues
# Then delete old key from GCP Console

# 4. Audit logs
# Review who/what used old key
gcloud logging read "protoPayload.resourceName=/projects/.../keys/..." --limit 100
```

---

## 📞 If Credentials Are Compromised

**Immediate Actions:**
1. ✅ Rotate all keys immediately
2. ✅ Check audit logs for unauthorized access
3. ✅ Delete compromised keys
4. ✅ Review and revoke suspicious permissions
5. ✅ Update all systems with new credentials
6. ✅ Change passwords associated with account

---

**Status**: ✅ Secure Credentials Setup Guide  
**Last Updated**: 2026-06-07  
**Author**: Satish Mudde  

🔒 **Never compromise on security!**
