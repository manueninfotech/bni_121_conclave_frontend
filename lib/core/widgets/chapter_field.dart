import 'package:flutter/material.dart';

import '../theme/cool_icons.dart';
import '../theme/tokens.dart';
import 'category_picker.dart';

/// The member's BNI chapter. With an organiser-made list it is a searchable
/// pick list (one spelling per chapter keeps the "keep chapter members apart"
/// seating rule accurate); a chapter missing from the list can still be typed.
/// Without a list it stays a plain text field. Optional either way.
class ChapterField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> chapters;
  const ChapterField({
    super.key,
    required this.controller,
    required this.chapters,
  });

  @override
  State<ChapterField> createState() => _ChapterFieldState();
}

class _ChapterFieldState extends State<ChapterField> {
  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return TextFormField(
        controller: widget.controller,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Chapter (optional)',
          prefixIcon: Icon(CoolIcons.usersGroup),
        ),
      );
    }
    final value = widget.controller.text.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final picked = await showListPicker(
          context,
          title: 'Your chapter',
          subtitle:
              'Search for your BNI chapter, or type it if it is not listed.',
          searchHint: 'Search chapters',
          items: widget.chapters,
          selected: value.isEmpty ? null : _listed(value),
          allowCustom: true,
        );
        if (picked != null) setState(() => widget.controller.text = picked);
      },
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: 'Chapter (optional)',
          prefixIcon: const Icon(CoolIcons.usersGroup),
          suffixIcon: value.isEmpty
              ? const Icon(CoolIcons.chevronDown)
              : IconButton(
                  icon: const Icon(CoolIcons.close, size: 18),
                  tooltip: 'Clear chapter',
                  onPressed: () => setState(() => widget.controller.clear()),
                ),
        ),
        child: value.isEmpty
            ? null
            : Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  /// The list's spelling of what the member has, so it shows as selected.
  String? _listed(String v) {
    for (final c in widget.chapters) {
      if (c.toLowerCase() == v.toLowerCase()) return c;
    }
    return v;
  }
}
