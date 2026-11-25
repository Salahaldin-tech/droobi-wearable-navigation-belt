import 'package:flutter/material.dart';

/// Shared page-title text: the same font family (LyonArabic), size and
/// weight on every screen, in Arabic and English.
///
/// Uses the theme's `titleLarge` style, which is the app's headline style.
/// Long titles wrap to a second line instead of being clipped or running
/// off screen; the font size never changes.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  static TextStyle style(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(height: 1.25);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: style(context),
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.start,
      ),
    );
  }
}

/// In-body page header used by screens without an AppBar.
///
/// It has the same height as an AppBar ([kToolbarHeight]) and centres the
/// title vertically, so titles line up at exactly the same height as the
/// AppBar titles on other screens. The title starts at the leading edge
/// (right in Arabic, left in English), followed by the help button; an
/// optional [trailing] widget sits at the opposite edge.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.help,
    this.trailing,
    this.horizontalPadding = 24,
  });

  final String title;
  final Widget help;
  final Widget? trailing;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kToolbarHeight),
        child: Row(
          // Top-aligned with computed insets: a one-line title is centred in
          // the 56px row (same height as AppBar titles), and a title that
          // wraps keeps its first line at that same height.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(top: _titleInset(context)),
                      child: PageTitle(title),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: help,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

double _titleInset(BuildContext context) {
  final style = PageTitle.style(context);
  final lineHeight = MediaQuery.textScalerOf(context)
          .scale(style.fontSize ?? 22) *
      (style.height ?? 1.25);
  return ((kToolbarHeight - lineHeight) / 2).clamp(0.0, kToolbarHeight);
}

/// Title spacing for AppBars using [AppBarPageTitle]: 24px like the in-body
/// headers on root pages, the standard spacing after a back button.
double pageTitleSpacing(BuildContext context) =>
    ModalRoute.of(context)?.impliesAppBarDismissal == true
        ? NavigationToolbar.kMiddleSpacing
        : 24;

/// Title widget for screens that use an AppBar: the same [PageTitle] next to
/// the help button. Pair with `centerTitle: false` so the title starts at
/// the leading edge like the in-body headers.
class AppBarPageTitle extends StatelessWidget {
  const AppBarPageTitle({super.key, required this.title, required this.help});

  final String title;
  final Widget help;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: PageTitle(title)),
        const SizedBox(width: 4),
        help,
      ],
    );
  }
}
