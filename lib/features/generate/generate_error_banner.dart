import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/job_fetch_hints.dart';

/// Inline error banner for the Generate form with optional expandable details.
class GenerateErrorBanner extends StatefulWidget {
  const GenerateErrorBanner({
    super.key,
    required this.error,
  });

  final Object error;

  @override
  State<GenerateErrorBanner> createState() => _GenerateErrorBannerState();
}

class _GenerateErrorBannerState extends State<GenerateErrorBanner> {
  var _showDetails = kDebugMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onError = theme.colorScheme.onErrorContainer;
    final message = messageForAppError(widget.error);
    final cause = widget.error is AppException ? (widget.error as AppException).cause : null;
    final details = formatErrorDetails(cause);
    final corsHint = corsHintForCause(cause);

    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: onError),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    key: const Key('generateError'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: onError),
                  ),
                ),
              ],
            ),
            if (corsHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                corsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: onError),
              ),
            ],
            if (details != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('generateErrorDetailsToggle'),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  style: TextButton.styleFrom(
                    foregroundColor: onError,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_showDetails ? 'Hide details' : 'Show details'),
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    details,
                    key: const Key('generateErrorDetails'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onError,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// User-facing message for any thrown [error] on the Generate screen.
String messageForAppError(Object error) {
  if (error is AppException) return error.message;
  return 'Generation failed. Check Settings and try again.';
}
