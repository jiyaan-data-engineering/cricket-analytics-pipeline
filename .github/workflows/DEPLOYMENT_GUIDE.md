# 🚀 GitHub Actions Deployment Guide

Complete guide for deploying to Dev, Staging, and Production environments using GitHub Actions.

---

## 📋 Overview

Three automated workflows handle deployment across environments with progressive approval gates:

| Workflow | Trigger | Approval | Target |
|----------|---------|----------|--------|
| **deploy-dev.yml** | Push to `develop` | Auto | 🟢 **DEV** |
| **deploy-stg.yml** | Create `v*.*.* tag` | Auto | 🟡 **STAGING** |
| **deploy-prod.yml** | Create `release-v*.*.* tag` | ⚠️ Manual | 🔴 **PROD** |

---

## 🔐 Prerequisites

### GitHub Secrets Required

**Development Environment:**
```
DEV_GCP_PROJECT_ID
DEV_SERVICE_ACCOUNT_EMAIL
DEV_WORKLOAD_IDENTITY_PROVIDER
DEV_TF_STATE_BUCKET
```

**Staging Environment:**
```
STG_GCP_PROJECT_ID
STG_SERVICE_ACCOUNT_EMAIL
STG_WORKLOAD_IDENTITY_PROVIDER
STG_TF_STATE_BUCKET
```

**Production Environment:**
```
PROD_GCP_PROJECT_ID
PROD_SERVICE_ACCOUNT_EMAIL
PROD_WORKLOAD_IDENTITY_PROVIDER
PROD_TF_STATE_BUCKET
```

### Setting Up Secrets

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add each secret with exact names above
4. Values come from GCP service account setup

---

## 🚀 Deployment Process

### **Phase 1: Development Deployment**

Automatically triggered when you push to `develop` branch.

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes to code or infrastructure
# (Edit Terraform files, SQL scripts, etc.)

# 3. Commit and push to develop
git add .
git commit -m "feat: Add new feature"
git push origin develop

# Workflow automatically:
# ✅ Validates configuration
# ✅ Plans infrastructure changes
# ✅ Applies Terraform
# ✅ Sets up BigQuery
# ✅ Runs tests
```

**View Progress:**
- Go to **Actions** tab
- Click **Deploy to DEV**
- Monitor in real-time

**Expected Duration:** ~5-10 minutes

---

### **Phase 2: Staging Deployment**

Manually triggered by creating a version tag.

```bash
# 1. Ensure develop is up to date
git checkout develop
git pull origin develop

# 2. Create version tag (follow semantic versioning)
git tag v1.0.0
git push origin v1.0.0

# Workflow automatically:
# ✅ Validates tag format
# ✅ Runs full test suite
# ✅ Plans infrastructure
# ✅ Applies Terraform
# ✅ Sets up BigQuery
# ✅ Runs integration tests
# ✅ Creates GitHub release
```

**View Progress:**
- Go to **Actions** tab
- Click **Deploy to STAGING**
- Look for tag `v1.0.0`

**Expected Duration:** ~10-15 minutes

---

### **Phase 3: Production Deployment**

Requires manual approval before applying changes.

```bash
# 1. Ensure tag was tested in staging
# (Usually create this after successful staging deployment)

# 2. Create release tag
git tag release-v1.0.0
git push origin release-v1.0.0

# Workflow pauses and waits for approval:
# ⏳ Manual review required
```

**Approve Deployment:**
1. Go to **Actions** tab
2. Click **Deploy to PRODUCTION**
3. Click **Review deployments**
4. Select **production** environment
5. Click **Approve and deploy**

**After Approval:**
- ✅ Plans infrastructure (production-grade)
- ✅ Security checks
- ✅ Cost estimation review
- ✅ Applies Terraform
- ✅ Sets up BigQuery
- ✅ Runs smoke tests
- ✅ Creates release notes

**Expected Duration:** ~15-20 minutes (after approval)

---

## 🔍 Workflow Jobs Breakdown

### Development Workflow (`deploy-dev.yml`)

```
Trigger: Push to develop
│
├─ validate ────────→ Checks Terraform format & syntax
├─ plan ────────────→ Plans infrastructure changes
├─ apply ───────────→ Applies Terraform
├─ bigquery-setup ──→ Creates/updates BigQuery objects
├─ test ────────────→ Runs unit tests
├─ validate-deploy ─→ Verifies resources created
└─ notify ──────────→ Success/failure notification
```

### Staging Workflow (`deploy-stg.yml`)

```
Trigger: Create v*.*.* tag
│
├─ pre-deployment ──→ Validates tag format
├─ validate ────────→ Full configuration check
├─ plan ────────────→ Plans production-like changes
├─ apply ───────────→ Applies Terraform
├─ bigquery-setup ──→ Creates BigQuery objects
├─ integration-test → Runs full test suite
├─ health-checks ───→ Verifies all systems
├─ notify ──────────→ Success notification
└─ release ─────────→ Creates GitHub release
```

### Production Workflow (`deploy-prod.yml`)

```
Trigger: Create release-v*.*.* tag
│
├─ pre-deployment ──→ Validates release tag
├─ validate ────────→ Strictest validation
├─ security ────────→ Security checks
├─ cost-estimate ───→ Estimates production costs
├─ plan ────────────→ Plans for production
├─ approval ───────→ ⏳ MANUAL APPROVAL GATE
├─ apply ───────────→ Applies infrastructure
├─ bigquery-setup ──→ Sets up BigQuery
├─ health-checks ───→ Critical smoke tests
├─ post-deploy ─────→ Success alerts & incident creation
└─ release-notes ───→ Creates detailed release
```

---

## 📊 Monitoring Deployments

### Real-Time Monitoring

1. Go to **Actions** tab
2. Select the workflow you want to monitor
3. Click the running workflow
4. Watch each job complete in order

### View Logs

```bash
# List recent runs
gh run list --workflow=deploy-dev.yml --limit=5

# View specific run
gh run view <run-id> --log

# Download artifacts
gh run download <run-id>
```

### Artifacts

Each workflow creates artifacts:
- `terraform-plan-dev` - Terraform plan file
- `terraform-plan-stg` - Staging Terraform plan
- `terraform-plan-prod` - Production Terraform plan

---

## ⚠️ Environment-Specific Behaviors

### Development (`develop` → Dev)
- **Auto-deploys** on every push
- **Lightweight resources** (2 workers, no monitoring)
- **No backups** configured
- **Fast feedback** for testing

### Staging (`v*.*.* tag` → Staging)
- **Full test suite** runs
- **Production-like** resources (3 workers, monitoring)
- **Daily backups** enabled
- **Requires tag creation** (explicit control)

### Production (`release-v*.*.* tag` → Prod)
- **Manual approval** required
- **Enterprise resources** (5 workers, full monitoring)
- **Hourly backups** enabled
- **Cost estimation** reviewed
- **Smoke tests** verified
- **Release notes** generated

---

## 🔄 Common Workflows

### Deploy Feature to Development

```bash
# 1. Create feature branch
git checkout -b feature/add-audit-logging

# 2. Make changes
# ... edit Terraform files, SQL, etc.

# 3. Commit and push
git add .
git commit -m "feat: Add comprehensive audit logging"
git push origin feature/add-audit-logging

# 4. Switch to develop and merge
git checkout develop
git merge feature/add-audit-logging

# 5. Push to develop (triggers auto-deployment)
git push origin develop

# Workflow runs automatically - view in Actions tab
```

### Promote from Staging to Production

```bash
# 1. Verify staging is working
# - Check GitHub Actions workflow passed
# - Check status at: https://console.cloud.google.com/bigquery

# 2. Create release tag
git tag release-v1.0.0

# 3. Push tag
git push origin release-v1.0.0

# 4. Approve in GitHub UI
# - Go to Actions → Deploy to PRODUCTION
# - Click Review deployments
# - Click Approve

# 5. Monitor production deployment
# View logs in Actions tab
```

### Rollback to Previous Version

```bash
# 1. Identify the version to rollback to
git tag -l | grep "v"
# Output: v0.9.0, v1.0.0, etc.

# 2. Create release from previous version
git tag release-v0.9.0 v0.9.0

# 3. Push tag
git push origin release-v0.9.0

# 4. Approve in GitHub UI
# (Same as promotion workflow)
```

---

## 🆘 Troubleshooting

### Workflow Won't Start

**Problem:** Push to develop, but workflow doesn't run

**Solution:**
1. Check paths in `on.push.paths` - ensure you changed a file in those paths
2. Verify branch is `develop` (not `development`)
3. Check branch protection rules - they can block workflows
4. Manually trigger: **Actions → Deploy to DEV → Run workflow**

### Plan Shows No Changes

**Problem:** Terraform plan shows "no changes"

**Solution:**
1. This is expected if resources already exist
2. Check if resources are already in Google Cloud
3. Run `terraform refresh` to update state
4. If truly no changes, it's safe to approve

### Approval Required Step Times Out

**Problem:** Approval step waiting forever

**Solution:**
1. Go to **Actions → Deploy to PRODUCTION**
2. Click **Review deployments**
3. Select **production** environment
4. Click **Approve and deploy**

### Integration Tests Fail in Staging

**Problem:** Staging workflow fails on integration tests

**Solution:**
1. Check test logs in workflow output
2. Verify BigQuery datasets were created
3. Verify GCP credentials have proper IAM roles
4. Run tests locally: `pytest tests/integration/`

---

## 🔐 Security Best Practices

✅ **DO:**
- Always review Terraform plan before approving
- Use distinct secrets for each environment
- Keep secrets rotated
- Monitor production deployments
- Test in staging before production

❌ **DON'T:**
- Commit secrets to repository
- Use same secrets for dev/prod
- Approve production without review
- Deploy directly to main branch
- Skip staging environment

---

## 📞 Getting Help

- **Workflow Logs:** Actions tab → [Workflow] → [Run] → specific job
- **Terraform Errors:** Search logs for "Error:"
- **Auth Errors:** Check GitHub secrets are correct
- **GCP Errors:** Check service account permissions
- **Local Testing:** Run terraform/tests locally first

---

## 📈 Monitoring & Alerts

### Set Up Notifications

1. **GitHub Settings → Notifications**
2. Enable notifications for workflow runs
3. Get alerts when deployments succeed/fail

### Monitor Production

After production deployment:
1. Watch error rates for 30 minutes
2. Check BigQuery data pipeline
3. Monitor dashboards for anomalies
4. Review audit logs for issues

---

**Status:** ✅ Ready to deploy! 🚀
