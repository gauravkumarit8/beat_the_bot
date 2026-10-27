import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies a boast to the clipboard so the player can paste it to a friend.
Future<void> copyBrag(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied. Now go and post it.')),
  );
}
