import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  _Lang _selected = _Lang.es;
  String? _content;
  bool    _loading = true;

  @override
  void initState() {
    super.initState();
    _load(_selected);
  }

  Future<void> _load(_Lang lang) async {
    setState(() { _loading = true; _content = null; });
    final text = await rootBundle.loadString(lang.assetPath);
    if (mounted) setState(() { _content = text; _loading = false; });
  }

  void _pick(_Lang lang) {
    if (lang == _selected) return;
    _selected = lang;
    _load(lang);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: _Lang.values.map((lang) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(lang.label),
                  selected: _selected == lang,
                  onSelected: (_) => _pick(lang),
                  visualDensity: VisualDensity.compact,
                ),
              )).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Markdown(
              data:            _content!,
              selectable:      true,
              padding:         const EdgeInsets.fromLTRB(16, 8, 16, 32),
              styleSheet:      MarkdownStyleSheet.fromTheme(theme).copyWith(
                h1:   theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                h2:   theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                h3:   theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                p:    theme.textTheme.bodyMedium,
                tableHead: const TextStyle(fontWeight: FontWeight.bold),
                tableBorder: TableBorder.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.8,
                ),
                blockquoteDecoration: BoxDecoration(
                  color:        theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Language enum ─────────────────────────────────────────

enum _Lang { es, en, fr }

extension _LangX on _Lang {
  String get label => switch (this) {
        _Lang.es => 'Español',
        _Lang.en => 'English',
        _Lang.fr => 'Français',
      };

  String get assetPath => switch (this) {
        _Lang.es => 'docs/MANUAL_ES.md',
        _Lang.en => 'docs/MANUAL_EN.md',
        _Lang.fr => 'docs/MANUAL_FR.md',
      };
}
