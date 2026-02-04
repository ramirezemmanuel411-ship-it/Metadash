# 🚀 AI Setup - 5 Minute Quick Start

## Step 1: Get Your FREE Groq API Key (2 mins)

1. Go to: https://console.groq.com/keys
2. Click "Sign up" (no credit card needed)
3. Create account with email
4. Click "Create New API Key"
5. Copy your key (starts with `gsk_`)

## Step 2: Add Key to `.env` File (1 min)

1. Open `.env` file in project root
2. Replace `your_groq_api_key_here` with your actual key:
   ```
   GROQ_API_KEY=gsk_abc123xyz...
   ```
3. Save file

## Step 3: Run App (2 mins)

```bash
flutter pub get
flutter run -d macos
```

## ✅ You're Done!

AI features are now active:

### Exercise Parsing
- Go to Dashboard → Dumbbell icon → Describe Workout
- Type: "ran 5k at high intensity for 30 minutes"
- AI automatically extracts type, duration, intensity, calories

### Food Chat (Coming Soon)
- Navigate to AI Chat screen (to be wired to FAB menu)
- Type: "large pepperoni pizza"
- AI estimates calories + macros
- Tap "Add to Diary" to save

---

## 💰 Cost?

**FREE!** Your Groq free tier gives you:
- 14,400 requests per day (600 per hour)
- Enough for 50+ workouts and 50+ food entries daily
- Zero cost for personal use

After that: $0.05 per 1M tokens (~0.10/month for heavy use)

---

## 🐛 Troubleshooting

### "No AI API keys configured"
→ Check `.env` file exists and has `GROQ_API_KEY=gsk_...`

### "Error loading .env"
→ Run `flutter clean && flutter pub get`

### AI returns garbage
→ Automatic fallback parsing activates (uses regex)

---

## 📖 Full Docs

See:
- [AI_INTEGRATION_GUIDE.md](AI_INTEGRATION_GUIDE.md) - Complete setup guide
- [AI_IMPLEMENTATION_SUMMARY.md](AI_IMPLEMENTATION_SUMMARY.md) - What was built

---

**Next Steps**:
1. ✅ Get Groq key and add to `.env`
2. ✅ Run app
3. ⏳ Test exercise parsing by logging a workout
4. ⏳ Wire AI Chat to FAB menu (coming soon)
5. ⏳ Update Diary timeline to display food entries

**Questions?** Check the full integration guide above.
