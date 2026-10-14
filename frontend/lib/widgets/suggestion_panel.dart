import 'dart:async';
import 'package:flutter/material.dart';
import '../services/suggest_api.dart';

/// Shows quick phrases (pinned) and suggestions for the detected venue.
///
/// Rules this widget follows:
///  - Nothing is ever sent or spoken automatically. The user must tap.
///  - Typed text can always be used exactly as written ("Use my own words").
///  - Suggestions are help only; they never block the user's own message.
class SuggestionPanel extends StatefulWidget {
  const SuggestionPanel({
    super.key,
    required this.api,
    required this.category,
    required this.onPhraseSelected,
    required this.onTypedTextSelected,
  });

  final SuggestApi api;
  final VenueCategory category;

  /// Called when the user taps a suggested/pinned phrase. Speak/send it here.
  final void Function(Phrase phrase) onPhraseSelected;

  /// Called when the user chooses their own typed text, unchanged.
  final void Function(String text) onTypedTextSelected;

  @override
  State<SuggestionPanel> createState() => _SuggestionPanelState();
}

class _SuggestionPanelState extends State<SuggestionPanel> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0; // ignore replies from older requests
  bool _loading = false;
  String? _error;
  SuggestResult? _result; // last good result stays visible if a request fails

  @override
  void initState() {
    super.initState();
    _fetch('');
  }

  @override
  void didUpdateWidget(covariant SuggestionPanel old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category) _fetch(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(text));
    setState(() {}); // refresh the "use my own words" button
  }

  Future<void> _fetch(String text) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.suggest(category: widget.category, query: text.trim());
      if (!mounted || id != _requestId) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } on SuggestException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final pinnedEnglish = r?.pinned.map((p) => p.english).toSet() ?? <String>{};
    // Hide suggestions that are already shown as quick phrases.
    final suggestions =
        r?.results.where((p) => !pinnedEnglish.contains(p.english)).toList() ?? const <Phrase>[];
    final typed = _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Type what you want to say (Sinhala or English)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
        ),
        if (typed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              onPressed: () => widget.onTypedTextSelected(_controller.text),
              icon: const Icon(Icons.send),
              label: const Text('Use my own words'),
            ),
          ),
        if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              TextButton(onPressed: () => _fetch(_controller.text), child: const Text('Retry')),
            ]),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              if (r != null && r.pinned.isNotEmpty) ...[
                const _SectionTitle('Quick phrases'),
                ...r.pinned.map((p) => _PhraseTile(phrase: p, onTap: widget.onPhraseSelected)),
              ],
              if (suggestions.isNotEmpty) ...[
                _SectionTitle(typed.isEmpty ? 'Common phrases here' : 'Suggestions'),
                if (r!.lowConfidence && typed.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'These may not match well. You can still use your own words.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ...suggestions.map((p) => _PhraseTile(phrase: p, onTap: widget.onPhraseSelected)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({required this.phrase, required this.onTap});
  final Phrase phrase;
  final void Function(Phrase) onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: () => onTap(phrase),
          title: Text(phrase.sinhala, style: const TextStyle(fontSize: 18)),
          subtitle: Text(phrase.english),
        ),
      );
}
