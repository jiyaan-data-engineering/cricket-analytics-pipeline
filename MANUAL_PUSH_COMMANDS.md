# Manual Commands: Push to GitHub (Copy & Paste)

If you prefer manual commands instead of the script, copy and paste these one by one in PowerShell.

---

## 📋 COPY & PASTE COMMANDS

### Command 1: Navigate to Project
```powershell
cd C:\satishMudde\claude\cricket-analytics-pipeline
```

### Command 2: Verify Files Exist
```powershell
dir README.md
```

### Command 3: Initialize Git
```powershell
git init
```

### Command 4: Configure Git (Replace with your info)
```powershell
git config --global user.name "Your Full Name"
git config --global user.email "your.email@example.com"
```

**Example:**
```powershell
git config --global user.name "Satish Mudde"
git config --global user.email "satish@jiyaan-institute.com"
```

### Command 5: Add GitHub Remote
```powershell
git remote add origin https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
```

### Command 6: Verify Remote
```powershell
git remote -v
```

Should show:
```
origin  https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git (fetch)
origin  https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git (push)
```

### Command 7: Stage All Files
```powershell
git add .
```

### Command 8: Check Status
```powershell
git status
```

Should show many files in green under "Changes to be committed"

### Command 9: Create Commit
```powershell
git commit -m "Initial commit: Cricket Analytics Pipeline - End-to-End Data Engineering Solution"
```

### Command 10: Create Master Branch
```powershell
git branch -M master
```

### Command 11: Push to GitHub
```powershell
git push -u origin master
```

**You'll be asked for:**
- Username: (leave blank or press Enter)
- Password: Paste your Personal Access Token

### Command 12: Verify Success
```powershell
git log --oneline -3
```

Should show your commit

### Command 13: Verify Remote
```powershell
git remote -v
```

Should show the GitHub URL

---

## 🎯 QUICK VERSION (All at Once)

Copy this entire block and paste into PowerShell:

```powershell
cd C:\satishMudde\claude\P1
dir README.md
git init
git config --global user.name "Satish Mudde"
git config --global user.email "satish@jiyaan-institute.com"
git remote add origin https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
git remote -v
git add .
git commit -m "Initial commit: Cricket Analytics Pipeline"
git branch -M master
git push -u origin master
git log --oneline -3
```

---

## 🔑 Personal Access Token (If Needed)

When pushed, if asked for password:

1. Go to: https://github.com/settings/tokens
2. Click: "Generate new token (classic)"
3. Check: "repo" + "admin:repo_hook"
4. Generate and copy the token
5. Paste it when asked for password (not your actual password!)

---

## ✅ Success Indicators

After `git push -u origin master`, you should see:
```
Counting objects: ...
Compressing objects: ...
Writing objects: ...
remote: Create a pull request for 'master' on GitHub by visiting:
remote: https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline/pull/new/master
```

Then visit:
https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline

And you should see all your files! ✅

---

## 🚀 Ready?

Copy the **Quick Version** above and paste it all at once into PowerShell. That's it!

Or use the automated script:
```powershell
.\PUSH_TO_GITHUB.ps1
```
