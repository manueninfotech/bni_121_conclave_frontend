import 'package:flutter/material.dart';

import '../constants/business_categories.dart';
import '../theme/tokens.dart';

/// The business-category chooser.
///
/// There are ~60 categories, and category is the single field the whole
/// matching engine seats people by — so choosing it should feel deliberate, not
/// like hunting through a cramped native dropdown menu. This is a normal-looking
/// form field that opens a full, searchable bottom sheet.
///
/// It is a [FormField], so it validates inside the same `Form` as every other
/// field on the screen.
class CategoryPickerField extends FormField<String> {
  CategoryPickerField({
    super.key,
    required String? value,
    required ValueChanged<String> onChanged,
    String label = 'Business category',
    String? helperText = 'No two people of the same category share a table',
  }) : super(
          initialValue: value,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Choose your business category' : null,
          builder: (field) {
            final context = field.context;
            return InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () async {
                FocusScope.of(context).unfocus();
                final picked = await showCategoryPicker(
                  context,
                  selected: field.value,
                );
                if (picked != null) {
                  field.didChange(picked);
                  onChanged(picked);
                }
              },
              child: InputDecorator(
                isEmpty: field.value == null || field.value!.isEmpty,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: const Icon(Icons.category_outlined),
                  helperText: helperText,
                  helperMaxLines: 2,
                  errorText: field.errorText,
                  suffixIcon: const Icon(Icons.expand_more_rounded),
                ),
                child: field.value == null || field.value!.isEmpty
                    ? null
                    : Text(field.value!, overflow: TextOverflow.ellipsis),
              ),
            );
          },
        );
}

/// Opens the picker and resolves to the chosen category, or null if dismissed.
Future<String?> showCategoryPicker(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CategoryPickerSheet(selected: selected),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final String? selected;
  const _CategoryPickerSheet({this.selected});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return bniBusinessCategories;
    return [
      for (final c in bniBusinessCategories)
        if (c.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Padding(
      // Lift the sheet above the keyboard while searching.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        // A tall sheet so most of the list is visible at once; the search box
        // narrows it fast for anyone who knows their category.
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business category',
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'No two people of the same category share a table.',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.md),
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search categories',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear',
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No category matches "$_query".',
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewPaddingOf(context).bottom + Gap.md,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        final isSelected = c == widget.selected;
                        return ListTile(
                          title: Text(c),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: context.scheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
