import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import 'models.dart';

class FoodSearchResults extends StatelessWidget {
  final String searchText;
  final List<FoodItem> recent;
  final void Function(FoodItem) onSelect;
  final void Function(String) onSearchChanged;

  const FoodSearchResults({
    super.key,
    required this.searchText,
    required this.recent,
    required this.onSelect,
    required this.onSearchChanged,
  });

  List<FoodItem> get filtered {
    final trimmed = searchText.trim();
    if (trimmed.isEmpty) return mockFoods;
    return mockFoods.where((f) => f.name.toLowerCase().contains(trimmed.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _searchField(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (searchText.trim().isEmpty && recent.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 6),
                    child: Text('Recent', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
                  _roundedList(
                    children: recent.map((i) => _FoodRow(item: i, onTap: () => onSelect(i))).toList(),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 6),
                  child: Text('Results', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                _roundedList(
                  children: filtered.map((i) => _FoodRow(item: i, onTap: () => onSelect(i))).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search foods',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                onChanged: onSearchChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundedList({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Container(color: Palette.lightStone, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: children[i],
            )),
            if (i != children.length - 1) const SizedBox(height: 0),
          ],
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const _FoodRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(item.macroLine, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('${item.calories} kcal', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
