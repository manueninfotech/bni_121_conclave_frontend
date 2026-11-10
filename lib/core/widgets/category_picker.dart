import 'package:flutter/material.dart';

import '../constants/business_categories.dart';
import '../theme/tokens.dart';
import 'package:conclave_1_2_1/core/theme/cool_icons.dart';

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
    List<String>? categories,
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
                 categories: categories,
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
                 prefixIcon: const Icon(CoolIcons.shapes),
                 helperText: helperText,
                 helperMaxLines: 2,
                 errorText: field.errorText,
                 suffixIcon: const Icon(CoolIcons.chevronDown),
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
  List<String>? categories,
}) {
  return showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Page tone, so the white A-Z cards read as cards.
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => _CategoryPickerSheet(
      selected: selected,
      categories: categories ?? bniBusinessCategories,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final String? selected;
  final List<String> categories;
  const _CategoryPickerSheet({this.selected, required this.categories});

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
    if (q.isEmpty) return widget.categories;
    return [
      for (final c in widget.categories)
        if (c.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final searching = _query.trim().isNotEmpty;

    // A-Z groups (one group when searching), each drawn as one white card.
    final groups = <(String, List<String>)>[];
    for (final c in results) {
      final key = searching
          ? ''
          : (c.toLowerCase() == 'other' ? '#' : c[0].toUpperCase());
      if (groups.isEmpty || groups.last.$1 != key) groups.add((key, []));
      groups.last.$2.add(c);
    }

    return Padding(
      // Lift the sheet above the keyboard while searching.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        // A tall sheet so most of the list is visible at once; the search box
        // narrows it fast for anyone who knows their category.
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business category',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'No two people of the same category share a table.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  _SearchPill(
                    controller: _search,
                    query: _query,
                    onChanged: (v) => setState(() => _query = v),
                    onClear: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CoolIcons.search,
                              size: 28,
                              color: context.scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: Gap.sm),
                            Text(
                              'No category matches "$_query".',
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Gap.xs),
                            Text(
                              'Try a shorter word, or pick Other.',
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        Gap.lg,
                        0,
                        Gap.lg,
                        MediaQuery.viewPaddingOf(context).bottom + Gap.lg,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, gi) {
                        final (letter, items) = groups[gi];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (letter.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  Gap.xs,
                                  gi == 0 ? 0 : Gap.md,
                                  0,
                                  Gap.xs,
                                ),
                                child: Text(
                                  letter,
                                  style: context.text.labelMedium?.copyWith(
                                    color: context.scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: context.scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < items.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        indent: Gap.lg,
                                        endIndent: Gap.lg,
                                        color: context.colors.hairline,
                                      ),
                                    _CategoryRow(
                                      label: items[i],
                                      selected: items[i] == widget.selected,
                                      onTap: () =>
                                          Navigator.pop(context, items[i]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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

/// A soft, borderless search pill (as on the Conclaves filters).
class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchPill({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final none = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search categories',
        prefixIcon: const Icon(CoolIcons.search, size: 20),
        filled: true,
        fillColor: context.scheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: none,
        enabledBorder: none,
        focusedBorder: none,
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(CoolIcons.close, size: 18),
                tooltip: 'Clear',
                onPressed: onClear,
              ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFB00E29);
    return Material(
      color: selected ? red.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? red : context.scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                const Icon(CoolIcons.circleCheckFill, size: 20, color: red),
            ],
          ),
        ),
      ),
    );
  }
}
