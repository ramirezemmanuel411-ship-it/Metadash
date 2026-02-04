# AI Integration Guide for MetaDash

## Overview

MetaDash now includes AI-powered features for:
- **Exercise parsing**: "ran 5k in 30 mins" → Duration, intensity, calories
- **Food estimation**: "large pepperoni pizza" → Calories + macros
- **AI Chat screen**: Save food estimates directly to Diary timeline

## 🚀 Quick Start

### 1. Get Your Free Groq API Key

1. Visit: https://console.groq.com/keys
2. Sign up (free, no credit card required)
3. Create a new API key
4. Copy your key

**Free Tier Limits:**
- 14,400 requests/day (600/hour)
- Perfect for personal use!

### 2. Add Your API Key

1. Open `.env` file in project root
2. Paste your key:
   ```
   GROQ_API_KEY=gsk_your_key_here
   ```

### 3. Run the App

```bash
flutter pub get
flutter run
```

That's it! AI features are now enabled.

---

## 📖 Features

### 1. AI Exercise Parsing

**Location**: Exercise Logging → Describe Workout

**How it works**:
```
User types: "HIIT for 20 mins, high intensity"

AI extracts:
- Type: "hiit"
- Duration: 20 minutes
- Intensity: "high"
- Estimated calories: 280
```

**Benefits**:
- No manual duration/intensity selection
- Automatic calorie estimation
- Confidence score shown if <70%

### 2. AI Food Chat

**Location**: Add Food → AI Chat (TODO: wire navigation)

**How it works**:
1. User types: "grilled chicken breast with brown rice"
2. AI responds with:
   - Item name
   - Calories + macros (P/C/F)
   - Confidence score
   - Assumptions (e.g., "Medium-sized portion")
3. User taps "Add to Diary"
4. Entry appears in Diary timeline

**Database**:
```sql
CREATE TABLE food_entries (
  id TEXT PRIMARY KEY,
  userId INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  name TEXT NOT NULL,
  calories INTEGER NOT NULL,
  proteinG INTEGER NOT NULL,
  carbsG INTEGER NOT NULL,
  fatG INTEGER NOT NULL,
  source TEXT NOT NULL,  -- 'ai_chat'
  confidence REAL,
  assumptions TEXT,      -- Stored as '|||' delimited
  rawInput TEXT
);
```

---

## 🔧 Integration Points

### Wiring AI Chat to Diary

**Current State**: AI Chat screen exists, but not yet linked from navigation

**To integrate**:

1. **From FAB Menu** (lib/shared/widgets/radial_menu.dart):
```dart
// Add AI Chat option to radial menu
if (item['label'] == 'AI Chat') {
  navigator.push(MaterialPageRoute(
    builder: (_) => AiChatScreen(userState: userState),
  ));
}
```

2. **From Add Food Flow**:
```dart
// In food search or diary screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AiChatScreen(
      userState: Provider.of<UserState>(context, listen: false),
    ),
  ),
);
```

### Diary Timeline Auto-Refresh

The Diary screen needs to display food entries from database.

**Current**: Diary shows calories/macros from `daily_logs` table
**Needed**: Also query `food_entries` and display in timeline

**Implementation TODO**:
```dart
// In diary_screen.dart, add StreamBuilder or FutureBuilder:
FutureBuilder<List<Map<String, dynamic>>>(
  future: userState.db.getFoodEntriesForDay(userId, selectedDay),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final entry = snapshot.data![index];
          return FoodEntryCard(entry: entry);
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

## 🔒 Security

### API Keys

- ✅ `.env` file is in `.gitignore` (won't be committed)
- ✅ `.env.example` provided for team members
- ✅ Keys loaded at app startup via `flutter_dotenv`

### Cost Protection

- Groq free tier: 14,400 req/day (more than enough)
- If you exceed: $0.05 per 1M tokens (~20,000 requests)
- OpenAI fallback (optional): ~$0.15/1M tokens

**Your estimated costs**:
- 100 exercises/day: FREE (Groq)
- 1000 exercises/day: ~$0.02/month
- Food chat 50x/day: FREE (Groq)

---

## 🛠️ Optional: OpenAI Fallback

If Groq is down, AI service automatically falls back to OpenAI.

### Setup:

1. Get OpenAI key: https://platform.openai.com/api-keys
2. Add to `.env`:
   ```
   OPENAI_API_KEY=sk-your_key_here
   ```
3. That's it! Automatic fallback enabled

**Cost**: GPT-4o-mini is $0.15/1M input tokens (~$0.30/month for normal use)

---

## 🧪 Testing

### 1. Test Exercise Parsing

```bash
# Run app
flutter run

# Navigate to:
Exercise Logging → Describe Workout

# Type:
"ran 5k in 30 minutes at medium intensity"

# Expected:
- AI parses duration (30 min)
- Estimates calories (~350)
- Saves to exercises table
```

### 2. Test Food Chat

```bash
# Navigate to AI Chat screen (once wired)

# Type:
"large pepperoni pizza, 3 slices"

# Expected:
- Shows calories (~900)
- Shows macros (P: 45g, C: 90g, F: 40g)
- Tap "Add to Diary"
- Entry saved to food_entries table
```

### 3. Verify Database

```bash
# Check food entries saved:
flutter run -d macos

# In app terminal:
SELECT * FROM food_entries;

# Should show:
# id | userId | timestamp | name | calories | source
# ------------------------------------------------
# 1  | 1      | 2026-...  | Pizza | 900     | ai_chat
```

---

## 🐛 Troubleshooting

### "No AI API keys configured"

**Solution**: Check `.env` file exists and contains:
```
GROQ_API_KEY=gsk_...
```

Run `flutter clean && flutter pub get` after adding .env

### "Error: Groq API error: 401"

**Solution**: Your API key is invalid or expired. Get a new one from:
https://console.groq.com/keys

### AI parsing returns garbage

**Solution**: AI might return invalid JSON. The service includes fallback regex parsing:
```dart
// In ai_service.dart
_fallbackExerciseParsing(description)
```

### Food entries not showing in Diary

**Solution**: Diary timeline needs to query `food_entries` table. See "Integration Points" section above.

---

## 📦 Files Added

### Models
- `lib/models/diary_entry_food.dart` - Food entry for diary timeline
- `lib/models/ai_food_estimate.dart` - AI response model

### Services
- `lib/services/ai_service.dart` - Groq + OpenAI client

### Screens
- `lib/features/food/ai_chat_screen.dart` - AI food chat UI

### Database
- `food_entries` table added to database schema

### Config
- `.env` - API keys (DO NOT COMMIT)
- `.env.example` - Template for team

---

## 🎯 Next Steps

1. ✅ AI service implemented (Groq + OpenAI fallback)
2. ✅ Exercise describe screen uses AI parsing
3. ✅ AI Chat screen with "Add to Diary" button
4. ✅ Database table for food entries
5. ⏳ **TODO**: Wire AI Chat to navigation (FAB menu or Add Food flow)
6. ⏳ **TODO**: Display food entries in Diary timeline
7. ⏳ **TODO**: Update daily_log macros when food entries added

---

## 💡 Cost Estimates

**Realistic monthly costs for personal use**:

| Feature | Daily Usage | Monthly Cost |
|---------|-------------|--------------|
| Exercise parsing | 3-5 workouts | FREE (Groq) |
| Food chat | 10-20 meals | FREE (Groq) |
| Heavy use | 50+ requests/day | $0.10-0.50 |
| Enterprise use | 1000+ requests/day | $5-10 |

**Conclusion**: For personal fitness tracking, you'll stay on Groq's free tier indefinitely.

---

## 📚 Resources

- **Groq Docs**: https://console.groq.com/docs/quickstart
- **OpenAI Docs**: https://platform.openai.com/docs/introduction
- **Flutter Dotenv**: https://pub.dev/packages/flutter_dotenv

---

## 🤝 Contributing

To add your API keys:

1. Copy `.env.example` to `.env`
2. Add your keys (never commit `.env`)
3. Share `.env.example` with team

**Team setup**:
```bash
# Each team member runs:
cp .env.example .env
# Then edit .env with their own keys
```

---

**Questions?** Check [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for more integration details.
