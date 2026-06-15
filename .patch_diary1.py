import re, textwrap

# ── New food entry card + timeline section replacement ──────────────────────
# We will replace the entire timeline `Expanded(child: SingleChildScrollView(...))` block
# and the `_openAddFoodSearch` call with a new approach.

new_timeline = '''
                Expanded(
                  child: _DiaryTimeline(
                    foodEntries: _foodEntries,
                    onAddAtHour: _openAddFoodSearch,
                    onDelete: (entry) async {
                      await widget.userState!.db.deleteFoodEntry(entry.id);
                      _loadFoodEntries();
                    },
                    onDuplicate: (entry) => _addEntryFromTemplate(entry),
                    onEdit: _editEntry,
                    onAddAgain: (entry) => _addEntryFromTemplate(
                      entry, timestamp: DateTime.now()),
                  ),
                ),
'''

old_timeline_start = '''                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(24, (index) {'''

old_timeline_end = '''                ),
              ],
            ),
          ),
          // Results modal overlay'''

with open("lib/features/diary/diary_screen.dart", "r") as f:
    src = f.read()

start = src.index(old_timeline_start)
end = src.index(old_timeline_end)

src = src[:start] + new_timeline.rstrip() + "\n" + " " * 14 + src[end:]

with open("lib/features/diary/diary_screen.dart", "w") as f:
    f.write(src)

print("timeline replaced OK")
print(f"file now {src.count(chr(10))+1} lines")
