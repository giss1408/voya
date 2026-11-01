import 'package:flutter/material.dart';

import 'theme.dart';

/// Placeholder block for loading states; shaped like the content it replaces.
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  const SkeletonBox({super.key, required this.height, this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: VoyaColors.line.withOpacity(0.6),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      );
}

/// Three list-row-shaped cards shown while data loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: ExcludeSemantics(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: Space.sm + 4),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 18, width: 180),
                          SizedBox(height: Space.sm),
                          SkeletonBox(height: 14, width: 120),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// Three trip-shaped cards shown while a search is running.
class TripListSkeleton extends StatelessWidget {
  const TripListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading trips',
        child: ExcludeSemantics(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: Space.sm + 4),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 18, width: 180),
                          SizedBox(height: Space.sm + 4),
                          SkeletonBox(height: 14),
                          SizedBox(height: Space.sm),
                          SkeletonBox(height: 12, width: 90),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// One sentence and (optionally) one action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xl),
        child: Column(
          children: [
            Icon(icon, size: 40, color: VoyaColors.inkSoft),
            const SizedBox(height: Space.sm + 4),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null) ...[
              const SizedBox(height: Space.sm),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

/// Human message plus Retry.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

enum BadgeTone { good, warn, info, crit }

/// Status chip: tinted background, readable text, never colour alone.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.good => (VoyaColors.goodTint, VoyaColors.good),
      BadgeTone.warn => (VoyaColors.warnTint, VoyaColors.warn),
      BadgeTone.info => (VoyaColors.infoTint, VoyaColors.indigo),
      BadgeTone.crit => (VoyaColors.critTint, VoyaColors.crit),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.sm + 2, vertical: Space.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: Space.xs),
          ],
          Text(
            label,
            style:
                TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Spinner sized for use inside a button.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

/// Section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm + 4),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
