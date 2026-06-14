# 🚀 Multi-Environment Terraform Refactoring Guide

## Overview

This guide walks you through transitioning your Terraform configuration from single-environment to multi-environment (dev/stg/prod) with modules and environment-specific variables.

---

## 📁 New Directory Structure

```
infrastructure/terraform/
├── main-multi-env.tf              # New: Modular main config
├── variables-multi-env.tf          # New: All environment variables
├── variables.tf                    # Old: Keep as-is for now
├── outputs.tf                      # Update to reference modules
│
├── environments/                   # New: Environment configs
│  ├── dev.tfvars                  # Development environment
│  ├── stg.tfvars                  # Staging environment
│  └── prod.tfvars                 # Production environment
│
├── modules/                        # New: Reusable modules
│  ├── bigquery/
│  │  ├── main.tf
│  │  ├── variables.tf
│  │  └── outputs.tf
│  │
│  ├── gcs/
│  │  ├── main.tf
│  │  ├── variables.tf
│  │  └── outputs.tf
│  │
│  └── [other modules]
│
├── bigquery.tf                     # Old: To be migrated to modules
├── gcs.tf                          # Old: To be migrated to modules
├── cloud_composer.tf               # Old: To be migrated to modules
└── main.tf                         # Old: Keep for reference
```

---

## 🔄 Migration Steps

### **Step 1: Review Current Configuration**

```bash
cd infrastructure/terraform

# List all resources created
terraform state list | head -20

# Get resource details
terraform state show google_bigquery_dataset.raw
```

### **Step 2: Initialize Terraform State Backend (Per Environment)**

```bash
# For Development
terraform init \
  -backend-config="bucket=dev-cricket-tf-state" \
  -backend-config="prefix=dev" \
  -reconfigure

# For Staging
terraform init \
  -backend-config="bucket=stg-cricket-tf-state" \
  -backend-config="prefix=stg" \
  -reconfigure

# For Production
terraform init \
  -backend-config="bucket=prod-cricket-tf-state" \
  -backend-config="prefix=prod" \
  -reconfigure
```

### **Step 3: Plan Infrastructure with New Configuration**

**For Development:**
```bash
# Validate new configuration
terraform validate -var-file="environments/dev.tfvars"

# Plan changes
terraform plan -var-file="environments/dev.tfvars" -out=dev.tfplan

# Review the plan output
terraform show dev.tfplan
```

### **Step 4: Apply Changes Incrementally**

**Start with non-destructive resources:**

```bash
# Apply BigQuery module first
terraform apply \
  -var-file="environments/dev.tfvars" \
  -target="module.bigquery" \
  dev.tfplan

# Then GCS module
terraform apply \
  -var-file="environments/dev.tfvars" \
  -target="module.gcs" \
  dev.tfplan
```

### **Step 5: Verify Migration**

```bash
# Check BigQuery datasets were created
bq ls --project_id=cricbuzz-satish-dev | grep "dev_"

# Check GCS buckets were created
gsutil ls | grep "dev-cricket"

# Verify in Terraform state
terraform state list | grep module.bigquery
terraform state list | grep module.gcs
```

---

## 🔐 Environment-Specific Workflows

### **Deploy to Development**

```bash
# Use development tfvars
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### **Deploy to Staging**

```bash
# Use staging tfvars (more resources, monitoring enabled)
terraform plan -var-file="environments/stg.tfvars"
terraform apply -var-file="environments/stg.tfvars"
```

### **Deploy to Production**

```bash
# Use production tfvars (max resources, full monitoring)
terraform plan -var-file="environments/prod.tfvars" -out=prod.tfplan

# Review carefully before applying
terraform show prod.tfplan

# Apply with approval
terraform apply prod.tfplan
```

---

## 📊 Key Differences Per Environment

| Resource | Dev | Staging | Production |
|----------|-----|---------|------------|
| **BigQuery** | Single datasets, no backups | Datasets with versioning | Full backups, monitoring |
| **GCS** | No versioning, 365-day lifecycle | Versioning, 365-day lifecycle | Versioning, retention = years |
| **Dataflow Workers** | 2 (n1-standard-2) | 3 (n1-standard-4) | 5 (n1-standard-8) |
| **Cloud Composer** | 3 nodes (n1-standard-4) | 3 nodes (n1-standard-4) | 4 nodes (n1-standard-8) |
| **Monitoring** | Disabled | Limited | Full + Alerts |

---

## 🎯 Using Variables in Workflows

### **Override variables at runtime:**

```bash
# Override a single variable
terraform plan \
  -var-file="environments/dev.tfvars" \
  -var="dataflow_max_workers=10"

# Multiple overrides
terraform plan \
  -var-file="environments/dev.tfvars" \
  -var="gcs_versioning_enabled=true" \
  -var="monitoring_enabled=true"
```

### **Use environment variables:**

```bash
export TF_VAR_gcp_project_id="cricbuzz-satish-dev"
export TF_VAR_environment="dev"

terraform plan -var-file="environments/dev.tfvars"
```

---

## 🔄 Rollback Procedure

If something goes wrong:

```bash
# View the previous state
terraform state show google_bigquery_dataset.raw

# Destroy problematic resources
terraform destroy \
  -var-file="environments/dev.tfvars" \
  -target="module.bigquery.google_bigquery_dataset.raw"

# Re-apply
terraform apply \
  -var-file="environments/dev.tfvars" \
  -target="module.bigquery"
```

---

## 📋 Checklist

- [ ] Review current Terraform state
- [ ] Create new environment directories
- [ ] Create and test modules (bigquery, gcs, etc.)
- [ ] Create environment-specific tfvars files
- [ ] Test plan with new configuration
- [ ] Apply changes incrementally
- [ ] Verify resources in GCP console
- [ ] Update GitHub workflows to use new structure
- [ ] Document any manual steps
- [ ] Archive old Terraform files

---

## ⚠️ Important Notes

1. **State Files**: Each environment should have separate state files
2. **Backend Config**: Update GCS backend per environment
3. **Service Accounts**: Remain the same, but can be parameterized
4. **Naming Convention**: Use `env_` or `env-` prefix for resources
5. **Destruction Safety**: Force destroy only allowed in dev

---

## 🆘 Troubleshooting

### **Issue: Variables not recognized**

```bash
# Ensure variable file is specified
terraform plan -var-file="environments/dev.tfvars"

# Check variable syntax
terraform validate
```

### **Issue: Module not found**

```bash
# Ensure modules directory exists
ls -la modules/bigquery/main.tf

# Re-init Terraform
terraform init -upgrade
```

### **Issue: State conflicts**

```bash
# Refresh state
terraform refresh -var-file="environments/dev.tfvars"

# Check for conflicts
terraform state list
```

---

## 📞 Next Steps

1. Implement GitHub Actions workflows with new structure
2. Add Cloud Composer module for Airflow
3. Add Dataflow template module
4. Add monitoring/alerting module
5. Document environment-specific secrets in GitHub

---

**Status**: Ready to implement! 🚀
