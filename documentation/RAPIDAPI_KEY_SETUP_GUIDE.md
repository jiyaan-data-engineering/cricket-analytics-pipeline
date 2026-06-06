# 🔑 RapidAPI Key Setup Guide

**How to Get Your RAPIDAPI_KEY and Set It Up**

---

## 📋 Step 1: Create RapidAPI Account

### Option A: New User
1. Go to **https://rapidapi.com/**
2. Click **"Sign Up"** (top right)
3. Choose sign-up method:
   - Email & password
   - GitHub account
   - Google account
4. Verify your email
5. Complete your profile

### Option B: Existing User
1. Go to **https://rapidapi.com/**
2. Click **"Sign In"** (top right)
3. Enter your credentials

---

## 🏏 Step 2: Subscribe to Cricbuzz Cricket API

### Find the API
1. After login, go to **https://rapidapi.com/cricketapilive/api/cricbuzz-cricket**
2. You should see:
   ```
   Cricbuzz Cricket API
   by cricketapilive
   ```

### Subscribe to API
1. Click **"Subscribe"** button
2. Choose a plan:
   - **Free Plan** ✅ (Recommended for testing)
     - 500 requests/month
     - Perfect for development
   
   - **Basic Plan** (Paid)
     - 5,000 requests/month
     - $10/month
   
   - **Pro Plan** (Paid)
     - 100,000 requests/month
     - $100/month

3. Click **"Subscribe to this API"**
4. Accept terms & complete subscription

---

## 🔐 Step 3: Get Your API Key

### Location
1. After subscribing, click your **Profile Icon** (top right)
2. Select **"Apps"** or **"My Apps"** from dropdown
3. Or go directly to: **https://rapidapi.com/settings/apps**

### Your API Key
You should see your application with:
- **X-RapidAPI-Key**: This is what you need!
- **X-RapidAPI-Host**: `cricbuzz-cricket.p.rapidapi.com`

Example:
```
X-RapidAPI-Key: abc123xyz789def456ghi789jkl012mno345
X-RapidAPI-Host: cricbuzz-cricket.p.rapidapi.com
```

---

## 💻 Step 4: Set Environment Variable

### Windows (PowerShell)

**Option 1: Temporary (Current Session Only)**
```powershell
$env:RAPIDAPI_KEY = "your-api-key-here"

# Verify it's set
echo $env:RAPIDAPI_KEY
```

**Option 2: Permanent (System-Wide)**
```powershell
# Run PowerShell as Administrator, then:
[Environment]::SetEnvironmentVariable("RAPIDAPI_KEY", "your-api-key-here", "User")

# Verify (might need to restart PowerShell)
echo $env:RAPIDAPI_KEY
```

**Option 3: Permanent (via Settings GUI)**
1. Press `Win + X` → **System**
2. Click **Advanced system settings**
3. Click **Environment Variables** button
4. Click **New** (under User variables)
5. Variable name: `RAPIDAPI_KEY`
6. Variable value: `your-api-key-here`
7. Click OK → OK
8. Restart PowerShell

### Windows (Command Prompt)

**Option 1: Temporary**
```cmd
set RAPIDAPI_KEY=your-api-key-here
echo %RAPIDAPI_KEY%
```

**Option 2: Permanent**
```cmd
setx RAPIDAPI_KEY "your-api-key-here"
```

---

## 🐧 Step 5: Linux/Mac Setup

### Temporary (Current Session)
```bash
export RAPIDAPI_KEY="your-api-key-here"

# Verify
echo $RAPIDAPI_KEY
```

### Permanent (Add to ~/.bashrc or ~/.zshrc)
```bash
# Edit your shell config file
nano ~/.bashrc    # For bash
# OR
nano ~/.zshrc     # For zsh

# Add this line at the end:
export RAPIDAPI_KEY="your-api-key-here"

# Save and exit, then reload:
source ~/.bashrc    # or source ~/.zshrc
```

---

## ✅ Step 6: Verify Setup

### Test Environment Variable
```bash
# PowerShell
echo $env:RAPIDAPI_KEY

# Bash/Linux/Mac
echo $RAPIDAPI_KEY
```

You should see your API key printed.

### Test with Python
```python
import os
api_key = os.getenv("RAPIDAPI_KEY")
print(f"API Key: {api_key}")

if api_key:
    print("✅ API Key is set correctly!")
else:
    print("❌ API Key is NOT set!")
```

### Test with Pipeline
```bash
cd ingestion
python fetch_batting_rankings.py
```

Expected output:
```
2026-06-07 10:30:45,123 - INFO - Fetching TEST batting rankings...
2026-06-07 10:30:46,456 - INFO - Fetching ODI batting rankings...
2026-06-07 10:30:47,789 - INFO - Fetching T20I batting rankings...
2026-06-07 10:30:48,012 - INFO - Uploaded CSV to gs://cricket-raw-data/batting/...
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "API key not found in config.yaml"

**Problem**: Environment variable not set

**Solution**:
```bash
# Check if variable is set
echo $env:RAPIDAPI_KEY  # PowerShell
echo $RAPIDAPI_KEY      # Bash

# If empty, set it:
$env:RAPIDAPI_KEY = "your-api-key-here"  # PowerShell
export RAPIDAPI_KEY="your-api-key-here"  # Bash
```

### Issue 2: 429 Error (Rate Limit Exceeded)

**Problem**: Exceeded API quota

**Solution**:
1. Check your plan limits at https://rapidapi.com/settings/apps
2. Wait for reset (usually monthly)
3. Consider upgrading plan if needed

### Issue 3: 401 Unauthorized Error

**Problem**: Invalid or expired API key

**Solution**:
1. Verify API key from https://rapidapi.com/settings/apps
2. Make sure you copied the full key (no spaces)
3. Check if subscription is still active
4. Re-subscribe if needed

### Issue 4: PowerShell Says "Path cannot be found"

**Problem**: Different user environment

**Solution**:
```powershell
# Check current user
whoami

# Set for current user (might need admin)
[Environment]::SetEnvironmentVariable("RAPIDAPI_KEY", "your-key", "User")

# Or just set for current session
$env:RAPIDAPI_KEY = "your-key"
```

---

## 📱 View Your API Usage

1. Go to **https://rapidapi.com/settings/apps**
2. Find your application
3. Click on it
4. You'll see:
   - Requests used this month
   - Requests remaining
   - Last request time
   - Subscription status

---

## 🔗 How It Works in the Pipeline

```
┌─────────────────────────────────────────┐
│ You Set Environment Variable            │
│ export RAPIDAPI_KEY="your-key"          │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Python Script Reads It                  │
│ api_key = os.getenv("RAPIDAPI_KEY")     │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Uses in API Headers                     │
│ headers = {                             │
│   "X-RapidAPI-Key": api_key,           │
│   "X-RapidAPI-Host": "..."             │
│ }                                       │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Requests Cricbuzz API                   │
│ GET /stats/v1/rankings/batsmen          │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Returns Batting Rankings Data           │
│ JSON with player rankings               │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Pipeline Processes & Uploads to GCS     │
│ Dataflow processes CSV → BigQuery       │
└─────────────────────────────────────────┘
```

---

## 🎯 Quick Start Summary

1. **Get Key**: https://rapidapi.com/settings/apps
2. **Set Env Var**: 
   ```bash
   export RAPIDAPI_KEY="your-key"  # Bash
   $env:RAPIDAPI_KEY = "your-key"  # PowerShell
   ```
3. **Verify**: 
   ```bash
   echo $RAPIDAPI_KEY  # Should show your key
   ```
4. **Run Pipeline**:
   ```bash
   cd ingestion
   python fetch_batting_rankings.py
   ```

---

## 📚 Additional Resources

- **RapidAPI Docs**: https://docs.rapidapi.com/
- **Cricbuzz API Docs**: https://rapidapi.com/cricketapilive/api/cricbuzz-cricket/details
- **Cricket Analytics Pipeline Docs**: See GCP_SETUP_GUIDE.md

---

**Status**: ✅ Complete  
**Last Updated**: 2026-06-07  
**Author**: Satish Mudde  

Your pipeline will start working as soon as you set the RAPIDAPI_KEY environment variable! 🚀
