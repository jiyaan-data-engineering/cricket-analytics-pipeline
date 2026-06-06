# GitHub Pages Setup

**Status**: Ready to deploy  
**Website URL**: https://jiyaan-data-engineering.github.io/cricket-analytics-pipeline/  

---

## ✅ What's Configured

1. **Jekyll Configuration** (`docs/_config.yml`)
   - Theme: Jekyll Theme Slate
   - Markdown processor: Kramdown
   - Sitemap and SEO plugins enabled

2. **GitHub Actions Workflow** (`.github/workflows/deploy-docs.yml`)
   - Automatically builds documentation on push to main
   - Deploys to GitHub Pages
   - Triggers only when docs/ folder changes

3. **Documentation Structure**
   - Entry point: `docs/README.md`
   - Master index: `docs/DOCUMENTATION.md`
   - 21 markdown files (auto-rendered as HTML)

---

## 🚀 Enable GitHub Pages

### Step 1: Go to Repository Settings

1. Go to https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline
2. Click **Settings** (top right)
3. Click **Pages** (left sidebar)

### Step 2: Configure GitHub Pages

1. **Source**: Select "GitHub Actions"
2. Click **Save**

That's it! The workflow will automatically build and deploy.

---

## 📍 Access Your Documentation

Once enabled, documentation will be available at:
```
https://jiyaan-data-engineering.github.io/cricket-analytics-pipeline/
```

The website will automatically serve:
- `docs/README.md` as the home page
- All other `.md` files as linked pages
- Automatic site navigation

---

## 📄 File Structure

```
Documentation/
├── README.md                    ← Home page
├── DOCUMENTATION.md             ← Navigation hub
├── _config.yml                  ← Jekyll config
├── TERRAFORM.md
├── AIRFLOW.md
├── BIGQUERY.md
├── DATAFLOW.md
├── ... (18 more files)
```

---

## 🔄 Automatic Deployment

Every time you push to `main` with changes in the `docs/` folder:
1. GitHub Actions workflow triggers
2. Jekyll builds the documentation
3. Website updates automatically at the URL above

No manual steps needed!

---

## 🎨 Customize Theme

To change the theme, edit `docs/_config.yml`:

```yaml
# Available Jekyll themes:
theme: jekyll-theme-slate          # Current (dark blue)
theme: jekyll-theme-cayman        # Light alternative
theme: jekyll-theme-midnight      # Dark alternative
theme: jekyll-theme-minimal       # Minimal
```

---

## ✅ Verification

After enabling GitHub Pages:
1. Go to repository Settings → Pages
2. Should show: "Your site is live at https://..."
3. Wait 1-2 minutes for first build
4. Visit the URL to see your documentation!

---

**Status**: Ready to enable! ✅  
**Next Step**: Go to repository Settings → Pages → select "GitHub Actions"
