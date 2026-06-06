# GitHub Repository Setup Guide

Complete instructions to set up and push the cricket-analytics-pipeline repository to GitHub.

---

## Step 1: Create Repository on GitHub

### 1.1 Go to GitHub
- Visit https://github.com/jiyaan-data-engineering/
- Click **New** button (or go to https://github.com/new)

### 1.2 Create Repository
- **Repository name**: `cricket-analytics-pipeline`
- **Description**: End-to-End Data Engineering Solution | Real-Time Analytics | Enterprise-Grade Architecture
- **Visibility**: Public
- **Initialize with**: 
  - ❌ Do NOT check "Add a README file"
  - ❌ Do NOT check "Add .gitignore"
  - ❌ Do NOT check "Choose a license"
  - ✅ We'll push our own files
- **Create repository**

### 1.3 Note the Repository URL
```
https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
```

---

## Step 2: Prepare Local Repository

### 2.1 Navigate to Project Directory
```bash
cd /path/to/cricket-analytics-pipeline
# Windows: cd c:\satishMudde\claude\cricket-analytics-pipeline
```

### 2.2 Check Current Status
```bash
# Check if git is already initialized
git status
# If error: "not a git repository", proceed to 2.3
```

### 2.3 Initialize Git (if needed)
```bash
# Initialize git
git init

# Set user configuration (one-time)
git config --global user.name "Your Name"
git config --global user.email "your.email@jiyaan-institute.com"

# Verify configuration
git config --list
```

### 2.4 Add Remote Repository
```bash
# Add origin remote pointing to GitHub
git remote add origin https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git

# Verify remote was added
git remote -v
# Should show:
# origin  https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git (fetch)
# origin  https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git (push)
```

---

## Step 3: Copy README to Root

### 3.1 Copy README File
```bash
# The README file should be in project root
# If you have README_GITHUB.md, rename/copy it:
cp README_GITHUB.md README.md

# Verify it exists
ls -la README.md  # Linux/Mac
# or
dir README.md    # Windows
```

---

## Step 4: Stage and Commit All Files

### 4.1 Check What Will Be Committed
```bash
# See all files that will be added
git status

# You should see files like:
# - README.md
# - LICENSE
# - CONTRIBUTING.md
# - .gitignore
# - config/
# - ingestion/
# - dataflow/
# - bigquery/
# - terraform/
# - airflow/
# - etc.
```

### 4.2 Add All Files to Staging
```bash
# Stage all files
git add .

# Verify staging
git status
# Should show files in "Changes to be committed"
```

### 4.3 Create Initial Commit
```bash
# Commit with descriptive message
git commit -m "Initial commit: Cricket Analytics Pipeline

- End-to-end data engineering solution
- Real-time analytics with BigQuery
- Apache Beam Dataflow processing
- Medallion architecture (raw/staging/curated)
- Infrastructure as Code (Terraform)
- Apache Airflow orchestration
- Production-ready with comprehensive documentation"

# Verify commit
git log
# Should show your initial commit
```

---

## Step 5: Create Master Branch

### 5.1 Check Current Branch
```bash
# Show current branch
git branch

# You should be on 'master' or 'main'
# To rename 'main' to 'master' (if needed):
# git branch -M master
```

### 5.2 Create Additional Branches (Optional)
```bash
# Create develop branch for development
git branch develop

# Create release branch for releases
git branch release

# List all branches
git branch -a
```

### 5.3 Set Master as Default (on GitHub)
You'll do this after pushing, via GitHub settings.

---

## Step 6: Push to GitHub

### 6.1 Push Master Branch
```bash
# Push master branch to GitHub
git push -u origin master

# The -u flag sets origin/master as tracking branch
# You'll see output like:
# Counting objects: ...
# Compressing objects: ...
# Writing objects: ...
# remote: Create a pull request for 'master' on GitHub...
```

### 6.2 Handle Authentication (if needed)
If you get an authentication error:

**Option A: Use Personal Access Token (Recommended)**
```bash
# Create token on GitHub:
# 1. Go to Settings → Developer Settings → Personal Access Tokens
# 2. Click "Generate new token"
# 3. Select scopes: repo, admin:repo_hook, admin:org_hook
# 4. Copy the token

# When prompted for password, paste the token instead
# Alternatively, add token to URL:
git remote set-url origin https://YOUR_TOKEN@github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
```

**Option B: Use SSH Key**
```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@jiyaan-institute.com"

# Add to SSH agent
ssh-add ~/.ssh/id_ed25519

# Add public key to GitHub
# 1. Copy: cat ~/.ssh/id_ed25519.pub
# 2. Go to GitHub Settings → SSH and GPG Keys
# 3. Click "New SSH key"
# 4. Paste the key

# Update remote URL to use SSH
git remote set-url origin git@github.com:jiyaan-data-engineering/cricket-analytics-pipeline.git

# Test connection
ssh -T git@github.com
```

### 6.3 Push All Branches
```bash
# Push develop branch (if created)
git push -u origin develop

# Push release branch (if created)
git push -u origin release

# Verify all branches are pushed
git branch -r
```

---

## Step 7: Verify on GitHub

### 7.1 Check Repository on GitHub
- Visit https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline
- Verify files are visible:
  - ✅ README.md
  - ✅ LICENSE
  - ✅ CONTRIBUTING.md
  - ✅ .gitignore
  - ✅ All folders (config/, ingestion/, dataflow/, etc.)

### 7.2 Check Commit History
```bash
# Locally
git log --oneline

# On GitHub: Click "Commits" tab
```

### 7.3 Verify Branch Protection (Optional)
```bash
# On GitHub Settings → Branches:
# - Select master as default branch
# - Optionally enable branch protection
# - Require pull request reviews before merge
# - Dismiss stale reviews when new commits pushed
# - Require status checks to pass
```

---

## Step 8: Additional GitHub Setup

### 8.1 Add Topics to Repository
On GitHub repository page → About section:

Add these topics:
- `data-engineering`
- `gcp`
- `bigquery`
- `dataflow`
- `apache-beam`
- `real-time-analytics`
- `educational`
- `open-source`
- `production-ready`
- `cloud-architecture`

### 8.2 Create GitHub Discussions
```
On repository:
1. Settings → Discussions → Enable
2. Create categories:
   - Announcements
   - General
   - Help
   - Show & Tell
```

### 8.3 Create Issue Templates
```
Create .github/ISSUE_TEMPLATE/:
1. bug_report.md
2. feature_request.md
3. question.md
```

### 8.4 Create PR Template
```
Create .github/PULL_REQUEST_TEMPLATE.md
```

---

## Quick Command Summary

```bash
# Navigate to project
cd /path/to/cricket-analytics-pipeline

# Initialize git
git init

# Configure git (first time only)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Add remote
git remote add origin https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git

# Copy README
cp README_GITHUB.md README.md

# Stage all files
git add .

# Commit
git commit -m "Initial commit: Cricket Analytics Pipeline"

# Create master branch (if needed)
git branch -M master

# Push to GitHub
git push -u origin master

# Verify
git branch -a
git remote -v
git log
```

---

## Continuous Development

### For Future Changes

```bash
# Check status
git status

# Stage changes
git add .

# Commit
git commit -m "Description of changes"

# Push
git push origin master
```

### Using Feature Branches

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ...

# Commit
git commit -m "Add new feature"

# Push feature branch
git push -u origin feature/new-feature

# On GitHub: Create Pull Request
# Review and merge

# Switch back to master
git checkout master
git pull origin master
```

---

## Troubleshooting

### Problem: "fatal: not a git repository"
```bash
# Solution: Initialize git
git init
```

### Problem: "Authentication failed"
```bash
# Solution 1: Use Personal Access Token
git remote set-url origin https://TOKEN@github.com/user/repo.git

# Solution 2: Use SSH key
git remote set-url origin git@github.com:user/repo.git
ssh-add ~/.ssh/id_ed25519
```

### Problem: "Branch already exists"
```bash
# Solution: Check branch name
git branch -a
# Then delete if needed
git branch -D branch-name
```

### Problem: "Failed to push"
```bash
# Solution: Pull first
git pull origin master
# Then push
git push origin master
```

### Problem: "Untracked files will be overwritten"
```bash
# Solution: Commit or stash changes
git status
git add .
git commit -m "Save changes"
# Then push
git push origin master
```

---

## Verification Checklist

- [ ] Repository created on GitHub
- [ ] Repository cloned/initialized locally
- [ ] Git configured with name and email
- [ ] Remote added pointing to GitHub
- [ ] README.md exists in root
- [ ] LICENSE file exists
- [ ] CONTRIBUTING.md exists
- [ ] .gitignore created
- [ ] All files staged with `git add .`
- [ ] Initial commit created
- [ ] Master branch created (if needed)
- [ ] Files pushed to GitHub
- [ ] Repository visible on GitHub
- [ ] All files visible in GitHub
- [ ] Commit history shows on GitHub
- [ ] Topics added to repository
- [ ] Discussions enabled
- [ ] Issue/PR templates created (optional)

---

## Next Steps

1. ✅ Push code to GitHub
2. Update GitHub profile with repository
3. Add project to GitHub organization
4. Enable GitHub Pages (optional)
5. Set up CI/CD with GitHub Actions (optional)
6. Create releases and tags
7. Announce to community

---

## Useful GitHub Commands

```bash
# View remote info
git remote -v

# Add collaborators
# On GitHub: Settings → Collaborators → Add people

# Create tags for releases
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0

# View all branches
git branch -a

# Delete local branch
git branch -d branch-name

# Delete remote branch
git push origin --delete branch-name

# Rename branch locally
git branch -m old-name new-name

# Rename branch remotely
git push origin --delete old-name
git push origin new-name

# View commit history
git log --oneline --graph --all

# Stash changes (temporary save)
git stash
git stash pop

# Revert last commit (keep changes)
git reset --soft HEAD~1

# Revert last commit (discard changes)
git reset --hard HEAD~1
```

---

## Resources

- [GitHub Docs](https://docs.github.com)
- [Git Documentation](https://git-scm.com/doc)
- [GitHub CLI](https://cli.github.com/)
- [SSH Keys Guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-data-secure-with-tokens)

---

**You're all set! Your repository is now on GitHub! 🚀**
