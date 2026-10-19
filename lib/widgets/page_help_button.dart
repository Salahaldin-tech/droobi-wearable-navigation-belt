import 'package:flutter/material.dart';

/// A reusable, accessible contextual-help button for a page title.
class PageHelpButton extends StatelessWidget {
  const PageHelpButton({
    super.key,
    required this.title,
    required this.titleAr,
    required this.description,
    required this.descriptionAr,
    this.tips = const [],
    this.tipsAr = const [],
    this.color = const Color(0xFF2F80ED),
  });

  final String title;
  final String titleAr;
  final String description;
  final String descriptionAr;
  final List<String> tips;
  final List<String> tipsAr;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final helpLabel = isArabic ? 'مساعدة: $titleAr' : 'Help: $title';

    return IconButton(
      tooltip: helpLabel,
      onPressed: () => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final activeTips = isArabic ? tipsAr : tips;
          return AlertDialog(
            icon: Icon(Icons.help_outline_rounded, color: color, size: 30),
            title: Text(
              isArabic ? 'مساعدة: $titleAr' : 'Help: $title',
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? descriptionAr : description,
                    style: const TextStyle(height: 1.45),
                  ),
                  if (activeTips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...activeTips.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(isArabic ? 'إغلاق' : 'Close'),
              ),
            ],
          );
        },
      ),
      icon: const Icon(Icons.help_outline_rounded),
      color: color,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: const EdgeInsets.all(8),
    );
  }
}
