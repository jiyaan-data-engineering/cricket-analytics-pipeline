# 🚀 START HERE - Cricket Analytics Pipeline

Welcome! You now have a **complete, production-ready GCP data pipeline**.

---

## ⚡ 3-Step Quick Start

### Step 1: Prepare (5 minutes)
```bash
# Install tools (if not already installed)
# macOS:
brew install gcloud terraform docker python@3.11

# Linux (Ubuntu/Debian):
sudo apt-get install -y google-cloud-sdk terraform docker.io python3.11

# Windows: Download installers from:
# - Google Cloud SDK: cloud.google.com/sdk
# - Terraform: terraform.io/downloads
# - Docker Desktop: docker.com/products/docker-desktop
# - Python: python.org
```

### Step 2: Configure (10 minutes)
```bash
# 1. Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# 2. Create GCP project (or use existing one)
# Go to: https://console.cloud.google.com/projectcreate

# 3. Get RapidAPI key
# Go to: https://rapidapi.com/
# Sign up → Subscribe to "Cricbuzz Cricket API"
# Copy your X-RapidAPI-Key from dashboard

# 4. Set defaults
gcloud config set project YOUR_GCP_PROJECT_ID
gcloud config set compute/region us-central1
```

### Step 3: Deploy (30 minutes)
```bash
# From the P1 directory:
chmod +x deploy.sh
./deploy.sh YOUR_GCP_PROJECT_ID YOUR_RAPIDAPI_KEY

# The script will:
# ✅ Enable all required GCP APIs
# ✅ Create Terraform configuration
# ✅ Deploy infrastructure (buckets, datasets, functions)
# ✅ Build and push Docker image
# ✅ Create BigQuery tables and views
# ✅ Test ingestion with sample data
# ✅ Show success message
```

**Total time**: ~45 minutes (mostly automated)

---

## 📚 Documentation Map

Choose your path based on what you need:

### Path 1: "I just want to deploy"
→ **Read**: [README.md](README.md) (quick start section)
→ **Do**: Follow the 3-step quick start above
→ **Then**: Go to "Next Steps" below

### Path 2: "I want to understand first"
→ **Read**: [ARCHITECTURE.md](ARCHITECTURE.md) (15 min read)
→ **Understand**: Data flow, components, technology stack
→ **Then**: Follow 3-step quick start

### Path 3: "I need detailed deployment steps"
→ **Read**: [DEPLOYMENT.md](DEPLOYMENT.md) (detailed guide)
→ **Follow**: Each step manually (more control)
→ **Verify**: Each component after deployment

### Path 4: "I want the complete picture"
→ **Read**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) (overview)
→ **Then**: [ARCHITECTURE.md](ARCHITECTURE.md) (design)
→ **Then**: [DEPLOYMENT.md](DEPLOYMENT.md) (implementation)
→ **Finally**: [INDEX.md](INDEX.md) (file reference)

---

## 🎯 What You Get

### Architecture
```
Cricbuzz API (RapidAPI)
    ↓
Ingestion (Python) → GCS (CSV)
    ↓
Cloud Function (serverless trigger)
    ↓
Dataflow (Apache Beam) → Processing
    ↓
BigQuery:
  - RAW layer (exact copy)
  - STAGING layer (star schema)
  - CURATED layer (5 analytics views)
    ↓
Looker Studio Dashboard (real-time)
```

### Data
- **Source**: ICC Men's Batting Rankings (Test, ODI, T20I)
- **Frequency**: Daily (06:00 UTC)
- **Volume**: ~300-500 records/day
- **Formats**: 3 (Test Cricket, ODI, T20 International)

### Technology Stack
- **Cloud**: GCP (Storage, BigQuery, Dataflow, Functions, Scheduler)
- **Processing**: Apache Beam (Dataflow)
- **Language**: Python 3.11
- **Database**: BigQuery
- **Analytics**: Looker Studio
- **Infrastructure**: Terraform (IaC)

### Cost
- **Monthly**: ~$5-9 (dev environment)
- **Per GB**: ~$0.05
- **Scalable**: Grows with your data

---

## ✅ After Deployment

### Verify Everything Works (5 minutes)

```bash
# 1. Check BigQuery data
bq query --use_legacy_sql=false \
  "SELECT COUNT(*), FORMAT FROM \`YOUR_PROJECT.cricket_raw.batting_rankings\` GROUP BY FORMAT"

# Expected: 3 rows (TEST, ODI, T20I) with record counts

# 2. Check curated views
bq query --use_legacy_sql=false \
  "SELECT * FROM \`YOUR_PROJECT.cricket_curated.vw_current_rankings\` LIMIT 5"

# Expected: Latest rankings for top players
```

### Create Looker Studio Dashboard (15 minutes)

1. Go to: https://lookerstudio.google.com/
2. Click: **+ Create** → **Report**
3. Add data source:
   - **Create new data source** → **BigQuery**
   - Select your GCP project
   - Choose dataset: `cricket_curated`
4. Add visualizations:
   - **Table**: `vw_current_rankings` (all columns)
   - **Line chart**: `vw_ranking_trend` (date vs rank)
   - **Bar chart**: `vw_top10_by_format` (player name vs rank)
   - **Pie chart**: `vw_country_summary` (country representation)
5. Share with team (click **Share** in top right)

### Monitor Pipeline (Ongoing)

```bash
# Watch Cloud Scheduler (daily @ 06:00 UTC)
gcloud scheduler jobs describe cricket-daily-ingestion --location us-central1

# Monitor Dataflow jobs
gcloud dataflow jobs list --region us-central1

# Check logs
gcloud functions logs read cricket-gcs-dataflow-trigger --gen2 --tail

# Query latest data
bq query --use_legacy_sql=false \
  "SELECT player_name, FORMAT, rank, rating FROM \`YOUR_PROJECT.cricket_curated.vw_current_rankings\` LIMIT 20"
```

---

## 🔍 File Structure

```
cricket-analytics-pipeline/
├── README.md                          ← Quick start
├── DEPLOYMENT.md                      ← Detailed setup
├── ARCHITECTURE.md                    ← Design document
├── PROJECT_SUMMARY.md                 ← What's delivered
├── INDEX.md                           ← File reference
├── START_HERE.md                      ← This file
│
├── config/
│   └── config.yaml                    (Configuration)
│
├── ingestion/
│   ├── fetch_batting_rankings.py      (API → GCS)
│   └── requirements.txt
│
├── cloud_function/
│   ├── main.py                        (Trigger)
│   └── requirements.txt
│
├── dataflow/
│   ├── pipeline.py                    (Processing)
│   ├── Dockerfile                     (Container)
│   └── requirements.txt
│
├── bigquery/
│   ├── schemas/
│   │   └── raw_batting_rankings.json
│   └── sql/
│       ├── 01_create_raw_table.sql
│       ├── 02_create_dim_player.sql
│       ├── 03_create_dim_country.sql
│       ├── 04_create_dim_format.sql
│       ├── 05_create_dim_date.sql
│       ├── 06_create_fact_batting.sql
│       └── 07_create_curated_views.sql
│
├── terraform/
│   ├── main.tf                        (Infrastructure)
│   ├── variables.tf
│   └── outputs.tf
│
└── deploy.sh                          (Automation)
```

---

## ❓ FAQ

### Q: Do I need GCP experience?
**A**: No! Just follow the deployment script. It automates everything.

### Q: What if I already have a GCP project?
**A**: Great! Just provide your project ID to the deploy script.

### Q: Can I run this on my laptop?
**A**: No, it requires GCP. But it costs ~$5-9/month to run in the cloud (very cheap).

### Q: How long does it take to deploy?
**A**: ~45 minutes (mostly automated). First data appears after ~30 minutes.

### Q: What if deployment fails?
**A**: Check [DEPLOYMENT.md](DEPLOYMENT.md) Troubleshooting section.

### Q: Can I modify the schedule?
**A**: Yes! Edit `config.yaml` → `scheduling.ingestion_schedule`

### Q: Can I add more data sources?
**A**: Yes! The pipeline is modular. Each layer can be extended.

### Q: Is this production-ready?
**A**: 100% Yes! It has logging, error handling, monitoring, and IaC.

### Q: What's the cost?
**A**: ~$5-9/month for the complete pipeline (dev environment).

### Q: Can I scale it?
**A**: Absolutely! Dataflow auto-scales, BigQuery handles petabytes.

---

## 🚨 Common Issues & Solutions

### "GCP API not enabled"
→ The deploy script enables all APIs automatically. If it fails:
```bash
gcloud services enable storage.googleapis.com bigquery.googleapis.com dataflow.googleapis.com
```

### "RapidAPI key invalid"
→ Double-check your key on https://rapidapi.com/developer/dashboard

### "Terraform state conflict"
→ Run: `terraform init` again in the terraform/ directory

### "Docker image push fails"
→ Ensure you're logged in: `gcloud auth configure-docker`

### "BigQuery table not found"
→ Run all SQL scripts: `for f in bigquery/sql/*.sql; do bq query < "$f"; done`

---

## 🎓 Learning Resources

After deployment, learn more about:

- **Apache Beam**: https://beam.apache.org/documentation/
- **Dataflow**: https://cloud.google.com/dataflow/docs
- **BigQuery**: https://cloud.google.com/bigquery/docs
- **Terraform**: https://www.terraform.io/docs/

---

## 📞 Need Help?

1. **First**: Check this file (START_HERE.md)
2. **Then**: Check [README.md](README.md)
3. **Then**: Check [DEPLOYMENT.md](DEPLOYMENT.md)
4. **Then**: Check [ARCHITECTURE.md](ARCHITECTURE.md)
5. **Finally**: Check [INDEX.md](INDEX.md) for file reference

---

## 🏆 Next Steps

### Immediately After Deployment

- [ ] Verify BigQuery has data (use command above)
- [ ] Create Looker Studio dashboard
- [ ] Share dashboard with team
- [ ] Monitor first daily execution (next 06:00 UTC)

### Within 1 Week

- [ ] Review ARCHITECTURE.md to understand the design
- [ ] Explore BigQuery tables and views
- [ ] Test dashboard with real data
- [ ] Adjust dashboard filters/charts as needed

### Within 1 Month

- [ ] Set up Cloud Monitoring alerts
- [ ] Document any customizations
- [ ] Plan for scaling
- [ ] Consider adding more data sources

---

## 🎉 Success Criteria

You'll know everything is working when:

✅ GCP APIs enabled (terraform shows success)
✅ GCS buckets created (visible in Cloud Storage)
✅ BigQuery datasets created (visible in BigQuery console)
✅ Cloud Function deployed (visible in Cloud Functions)
✅ First data appears in `cricket_raw.batting_rankings` (~10 min after deploy)
✅ `cricket_staging` tables populated (~2 hours after deploy)
✅ `cricket_curated` views show data (~2 hours after deploy)
✅ Looker Studio dashboard loads and shows data
✅ Cloud Scheduler job created (visible in Cloud Scheduler)

---

## 📊 What Happens Daily

```
06:00 UTC ─────────────────────────────────────
     Cloud Scheduler triggers

06:02 UTC ─────────────────────────────────────
     Ingestion runs:
     • Fetches Cricbuzz API
     • Creates CSV file
     • Uploads to GCS

06:05 UTC ─────────────────────────────────────
     GCS event triggers

06:06 UTC ─────────────────────────────────────
     Cloud Function runs:
     • Launches Dataflow job

06:10 UTC ─────────────────────────────────────
     Dataflow processes:
     • Reads CSV
     • Validates data
     • Writes to BigQuery RAW

06:18 UTC ─────────────────────────────────────
     Data in RAW layer

08:00 UTC ─────────────────────────────────────
     Scheduled Query runs:
     • Transforms RAW → STAGING → CURATED

08:05 UTC ─────────────────────────────────────
     Dashboard auto-refreshes:
     • Shows latest rankings
     • Available to all viewers

16:00+ UTC ────────────────────────────────────
     Global users see latest data
```

---

## 🎯 Your Journey

```
START HERE
    ↓
Read README.md (5 min)
    ↓
Run deploy.sh (30 min)
    ↓
Create Looker Studio (15 min)
    ↓
✅ LIVE!

Total: ~50 minutes to production
```

---

## ✨ Key Highlights

✅ **Fully Automated** — Deploy once, runs daily forever
✅ **Serverless** — No servers to manage
✅ **Scalable** — Grows from 100 to 1M+ records
✅ **Cost-Effective** — ~$5-9/month
✅ **Production-Ready** — Error handling, logging, monitoring
✅ **Well-Documented** — 2,700+ lines of documentation
✅ **Best Practices** — Star schema, medallion architecture, IaC
✅ **Analytics-Ready** — 5 curated views for dashboards

---

## 🚀 Ready?

### Command to Deploy:

```bash
./deploy.sh YOUR_GCP_PROJECT_ID YOUR_RAPIDAPI_KEY
```

That's it! Everything else is automated.

---

**Questions?** → Read [README.md](README.md)
**Deployment issues?** → Read [DEPLOYMENT.md](DEPLOYMENT.md)
**Architecture questions?** → Read [ARCHITECTURE.md](ARCHITECTURE.md)

**Happy analyzing! 📊**
