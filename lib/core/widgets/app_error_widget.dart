import 'package:flutter/material.dart';

class AppErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              friendlyMessage(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon:  const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String friendlyMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('unreachable')) {
      return 'Check your internet connection and try again.';
    }
    if (msg.contains('unauthorized') ||
        msg.contains('permission') ||
        msg.contains('not authorized') ||
        msg.contains('jwt')) {
      return 'You don\'t have permission to view this.';
    }
    if (msg.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    if (msg.contains('not found') || msg.contains('404')) {
      return 'The requested data could not be found.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
