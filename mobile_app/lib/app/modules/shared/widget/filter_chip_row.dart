import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class FilterChipOption {
  const FilterChipOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Horizontal filter chips used on Home and Entries.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  final List<FilterChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AnimatedFilterTrack(
            options: options,
            selected: selected,
            onSelected: onSelected,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Telegram-style sliding brand thumb across filter options.
class _AnimatedFilterTrack extends StatelessWidget {
  const _AnimatedFilterTrack({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  static const _gap = 4.0;
  static const _pad = 3.0;
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedIndex = options.indexWhere((o) => o.value == selected);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    final count = options.length;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.settledSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final innerWidth = constraints.maxWidth;
            final itemWidth = count == 0
                ? 0.0
                : (innerWidth - (count - 1) * _gap) / count;
            final thumbLeft = index * (itemWidth + _gap);

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedPositioned(
                  duration: _animDuration,
                  curve: _animCurve,
                  left: thumbLeft,
                  width: itemWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.brand,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: colors.brand.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: _FilterPill(
                          label: options[i].label,
                          selected: selected == options[i].value,
                          onTap: () => onSelected(options[i].value),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        splashColor: colors.brand.withValues(alpha: 0.1),
        highlightColor: colors.brand.withValues(alpha: 0.05),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                height: 1.1,
                color: selected ? colors.onBrand : colors.ink,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Search field + filter button used on Home and Entries.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    required this.onFilterTap,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final TextEditingController? controller;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final bool _ownsController;
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChanged() {
    final next = _controller.text.trim().isNotEmpty;
    if (next == _hasText || !mounted) return;
    setState(() => _hasText = next);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused ? colors.brand : colors.line,
                width: _focused ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.ink.withValues(alpha: _focused ? 0.07 : 0.04),
                  blurRadius: _focused ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _focused
                          ? Color.alphaBlend(
                              colors.brand.withValues(alpha: 0.1),
                              colors.surface,
                            )
                          : colors.settledSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: _focused ? colors.brand : colors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    cursorColor: colors.brand,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: colors.muted.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 14.5,
                      ),
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_hasText)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: _clear,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: colors.muted,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onFilterTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: colors.brand.withValues(alpha: 0.1),
            highlightColor: colors.brand.withValues(alpha: 0.05),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.line),
                boxShadow: [
                  BoxShadow(
                    color: colors.ink.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded, size: 22, color: colors.brand),
            ),
          ),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: foreground,
        ),
      ),
    );
  }
}
