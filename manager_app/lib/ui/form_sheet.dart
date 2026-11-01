import 'package:flutter/material.dart';

import 'package:voya_ui/voya_ui.dart';
import 'user_message.dart';

/// Modal bottom sheet for one creation task. [onSubmit] runs only when the
/// form validates; a thrown error is shown inline, success closes the sheet.
Future<bool?> showFormSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required List<Widget> fields,
  required GlobalKey<FormState> formKey,
  required Future<void> Function() onSubmit,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VoyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.md)),
      ),
      builder: (_) => _FormSheet(
        title: title,
        submitLabel: submitLabel,
        fields: fields,
        formKey: formKey,
        onSubmit: onSubmit,
      ),
    );

class _FormSheet extends StatefulWidget {
  final String title;
  final String submitLabel;
  final List<Widget> fields;
  final GlobalKey<FormState> formKey;
  final Future<void> Function() onSubmit;
  const _FormSheet({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.md, Space.md, Space.md,
          Space.md + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: text.titleLarge),
              const SizedBox(height: Space.md),
              for (final f in widget.fields) ...[
                f,
                const SizedBox(height: Space.md),
              ],
              if (_error != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: VoyaColors.crit),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(_error!,
                          style:
                              text.bodySmall?.copyWith(color: VoyaColors.crit)),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
              ],
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const ButtonSpinner() : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
