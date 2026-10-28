import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/challenge.dart';
import '../core/theme.dart';

/// Asks for a friend's challenge code. Pops a [Challenge] when it is valid.
class ChallengeCodeDialog extends StatefulWidget {
  const ChallengeCodeDialog({super.key});

  @override
  State<ChallengeCodeDialog> createState() => _ChallengeCodeDialogState();
}

class _ChallengeCodeDialogState extends State<ChallengeCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _submit() {
    final challenge = Challenge.parse(_controller.text);
    if (challenge == null) {
      setState(() => _error = 'That code does not look right.');
      return;
    }
    Navigator.of(context).pop(challenge);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Challenge code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the code, or the whole message, your friend sent you.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'BTB-MH-1K9X2-7-Q',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _paste, child: const Text('PASTE')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _submit, child: const Text('PLAY')),
      ],
    );
  }
}
