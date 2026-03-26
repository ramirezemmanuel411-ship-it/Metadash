# Floating Action Hub

A draggable, persistent floating action button with radial menu functionality.

## Features

### 1. **Single FAB Design**
- Single beige-aesthetic '+' button
- Preserves app's warm neutral color scheme
- No second persistent floating button

### 2. **User Interactions**
- **Tap**: Quick add food (primary action)
- **Long-press**: Opens radial menu with 4 options
- **Drag**: Repositionable anywhere on screen

### 3. **Smart Positioning**
- **Edge Snapping**: Automatically snaps to left or right edge on release
- **Position Memory**: Saves position using SharedPreferences
- **Collision Avoidance**: Can be moved away from timeline trash icons
- **Safe Area Aware**: Respects notches and system UI

### 4. **Radial Menu**
Four evenly-spaced actions appear on long-press:
- **AI Assistant** (✨): Opens AI chat for meal/workout suggestions
- **Add Food** (🍽️): Opens food search screen
- **Add Workout** (💪): Opens exercise logging
- **Add Weight** (⚖️): Weight logging (placeholder for future implementation)

### 5. **Animation**
- Scale animation: 0 → 1 with bounce (easeOutBack curve)
- Fade animation: 0 → 1 (easeOut curve)
- 180ms duration for smooth transitions
- Backdrop dimming when menu is open

### 6. **Technical Details**
- Uses `OverlayEntry` for menu layer (above all UI)
- `AnimationController` with `SingleTickerProviderStateMixin`
- Haptic feedback on long-press and menu selection
- Radial menu items positioned using polar coordinates
- Automatic quadrant detection to avoid screen edges

## Usage

```dart
FloatingActionHub(
  onAddFood: _openAddFood,
  onOpenAI: _openAiAssistant,
  onAddWorkout: _openAddWorkout,
  onAddWeight: _openAddWeight,
  fabColor: Palette.forestGreen,
  backgroundColor: Palette.warmNeutral,
)
```

## Implementation Notes

### Position Calculation
- FAB defaults to bottom-right if no saved position
- Snaps to nearest horizontal edge (left/right) on drag end
- Vertical position is clamped to safe area bounds

### Radial Menu Layout
- Items arranged in circle around FAB center
- Radius: 100 logical pixels from FAB center
- Quadrant selection based on FAB position (prevents off-screen items)
- Positions clamped to screen bounds with 16px padding

### State Management
- Position persisted in SharedPreferences (`fab_position_x`, `fab_position_y`)
- Menu open/closed state managed locally in widget
- Overlay removed on menu close to free resources

## Future Enhancements
- [ ] Weight logging screen integration
- [ ] Custom haptic patterns per action
- [ ] Configurable menu items
- [ ] Theme-aware colors from app settings
