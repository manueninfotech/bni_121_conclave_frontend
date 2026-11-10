import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cool_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/conclave_filters.dart';

/// Quick filters under the Ongoing / Upcoming / Past switcher. The chips
/// adapt to the tab: Ongoing = Search, Mine; Upcoming = Search, Mine, Region,
/// When; Past = Search, Attended, Region. Search expands in place.
class ConclaveFilterBar extends ConsumerStatefulWidget {
  final int tab;
  final List<String> regions;
  const ConclaveFilterBar({super.key, required this.tab, required this.regions});

  @override
  ConsumerState<ConclaveFilterBar> createState() => _ConclaveFilterBarState();
}

class _ConclaveFilterBarState extends ConsumerState<ConclaveFilterBar> {
  late final TextEditingController _q =
      TextEditingController(text: ref.read(conclaveFiltersProvider).query);
  final _focus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searching = _q.text.isNotEmpty;
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _closeSearch() {
    _q.clear();
    ref.read(conclaveFiltersProvider.notifier).setQuery('');
    _focus.unfocus();
    setState(() => _searching = false);
  }

  Future<void> _pickRegion() async {
    final current = ref.read(conclaveFiltersProvider).region;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _OptionSheet(
        title: 'Region',
        options: ['All regions', ...widget.regions],
        selected: current ?? 'All regions',
      ),
    );
    if (picked == null) return;
    ref
        .read(conclaveFiltersProvider.notifier)
        .setRegion(picked == 'All regions' ? null : picked);
  }

  Future<void> _pickWhen() async {
    final current = ref.read(conclaveFiltersProvider).when;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _OptionSheet(
        title: 'When',
        options: [for (final w in ConclaveWhen.values) w.label],
        selected: current.label,
      ),
    );
    if (picked == null) return;
    ref
        .read(conclaveFiltersProvider.notifier)
        .setWhen(ConclaveWhen.values.firstWhere((w) => w.label == picked));
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(conclaveFiltersProvider);
    final n = ref.read(conclaveFiltersProvider.notifier);
    final tab = widget.tab;

    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _searching
            ? _SearchField(
                key: const ValueKey('search'),
                controller: _q,
                focus: _focus,
                onChanged: n.setQuery,
                onClose: _closeSearch,
              )
            : ListView(
                key: const ValueKey('chips'),
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(
                    icon: CoolIcons.search,
                    label: 'Search',
                    selected: false,
                    onTap: _openSearch,
                  ),
                  _Chip(
                    icon: CoolIcons.userCheckCorner,
                    label: tab == 2 ? 'Attended' : 'Mine',
                    selected: f.mineOnly,
                    onTap: n.toggleMine,
                  ),
                  if (tab != 0 && widget.regions.isNotEmpty)
                    _Chip(
                      icon: CoolIcons.mapPin,
                      label: f.region ?? 'Region',
                      selected: f.region != null,
                      dropdown: true,
                      onTap: _pickRegion,
                    ),
                  if (tab == 1)
                    _Chip(
                      icon: CoolIcons.calendar,
                      label: f.when == ConclaveWhen.any ? 'When' : f.when.label,
                      selected: f.when != ConclaveWhen.any,
                      dropdown: true,
                      onTap: _pickWhen,
                    ),
                  if (f.isActive)
                    _Chip(
                      icon: CoolIcons.close,
                      label: 'Clear',
                      selected: false,
                      quiet: true,
                      onTap: () {
                        _q.clear();
                        n.clear();
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool dropdown;
  final bool quiet;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dropdown = false,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = selected ? scheme.surface : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: Gap.sm),
      child: Material(
        color: selected
            ? scheme.onSurface
            : (quiet ? Colors.transparent : scheme.surfaceContainerLowest),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected || quiet ? Colors.transparent : context.colors.hairline,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: quiet ? scheme.onSurfaceVariant : fg),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: quiet ? scheme.onSurfaceVariant : fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (dropdown) ...[
                const SizedBox(width: 2),
                Icon(CoolIcons.chevronDown, size: 14, color: fg),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(CoolIcons.search, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: context.text.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Conclave, venue or region',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close search',
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
          icon: Icon(CoolIcons.close, size: 18, color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// A simple single-choice list in a bottom sheet; pops the chosen option.
class _OptionSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
            child: Text(title,
                style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    title: Text(o),
                    trailing: o == selected
                        ? Icon(CoolIcons.check, color: context.scheme.onSurface)
                        : null,
                    onTap: () => Navigator.pop(context, o),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
