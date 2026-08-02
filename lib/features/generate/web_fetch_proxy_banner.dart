import 'package:flutter/material.dart';

/// Info banner shown on web when no job-fetch proxy is configured.
class WebFetchProxyBanner extends StatelessWidget {
  const WebFetchProxyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('webFetchProxyBanner'),
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'On web, many job sites block direct fetches (CORS). Add a '
                'job fetch proxy URL in Settings, or paste the job description '
                'below if fetching fails.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
