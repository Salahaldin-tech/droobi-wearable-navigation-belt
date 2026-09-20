import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/university_location.dart';
import '../../state/university_locations_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';

class UniversityLocationsScreen extends ConsumerWidget {
  const UniversityLocationsScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2F80ED);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textColor = Color(0xFF111111);
  static const Color _secondaryText = Color(0xFF6B7280);

  // ===========================================================================
  // FIGMA DATA
  // ===========================================================================

  static const List<_UniversityItem> _colleges = [
    _UniversityItem(
      name: 'Faculty of Allied Medical Sciences',
      nameAr: 'كلية العلوم الطبية المساعدة',
      aliases: [
        'Faculty of Allied Medical Sciences',
        'Allied Medical Sciences',
        'AMS',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Arts and Education',
      nameAr: 'كلية الآداب والتربية',
      aliases: [
        'Faculty of Arts and Education',
        'Faculty of Arts',
        'Arts and Education',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Business',
      nameAr: 'كلية الأعمال',
      aliases: [
        'Faculty of Business',
        'Business',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Dentistry',
      nameAr: 'كلية طب الأسنان',
      aliases: [
        'Faculty of Dentistry',
        'Dentistry',
        'DEN-A',
        'DEN-B',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Engineering',
      nameAr: 'كلية الهندسة',
      aliases: [
        'Faculty of Engineering',
        'Faculty of Engineering and Information Technology',
        'Faculty of Engineering and IT',
        'Engineering and Information Technology',
        'EIT',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Information Technology',
      nameAr: 'كلية تكنولوجيا المعلومات',
      aliases: [
        'Faculty of Information Technology',
        'Information Technology',
        'IT',
        'EIT',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Law',
      nameAr: 'كلية القانون',
      aliases: [
        'Faculty of Law',
        'Law',
        'LAW',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Medicine',
      nameAr: 'كلية الطب',
      aliases: [
        'Faculty of Medicine',
        'Medicine',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Nursing',
      nameAr: 'كلية التمريض',
      aliases: [
        'Faculty of Nursing',
        'Nursing',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Pharmacy',
      nameAr: 'كلية الصيدلة',
      aliases: [
        'Faculty of Pharmacy',
        'Pharmacy',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Science',
      nameAr: 'كلية العلوم',
      aliases: [
        'Faculty of Science',
        'Faculty of Sciences',
        'Science',
        'A&S',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Sports Sciences',
      nameAr: 'كلية علوم الرياضة',
      aliases: [
        'Faculty of Sports Sciences',
        'Sports Sciences',
      ],
    ),
  ];

  static const List<_UniversityItem> _gates = [
    _UniversityItem(
      name: 'Gate 1',
      nameAr: 'البوابة ١',
      aliases: [
        'Gate 1',
        'G1',
      ],
    ),
    _UniversityItem(
      name: 'Gate 2',
      nameAr: 'البوابة ٢',
      aliases: [
        'Gate 2',
        'G2',
      ],
    ),
    _UniversityItem(
      name: 'Gate 3',
      nameAr: 'البوابة ٣',
      aliases: [
        'Gate 3',
        'G3',
        'Gate 3 University Visitors Gate',
      ],
    ),
    _UniversityItem(
      name: 'Gate 4',
      nameAr: 'البوابة ٤',
      aliases: [
        'Gate 4',
        'G4',
      ],
    ),
    _UniversityItem(
      name: 'Gate 5',
      nameAr: 'البوابة ٥',
      aliases: [
        'Gate 5',
        'G5',
      ],
    ),
  ];

  static const List<_UniversityItem> _facilities = [
    _UniversityItem(
      name: 'Cafeteria',
      nameAr: 'الكافتيريا',
      aliases: [
        'Cafeteria',
        'Shopping Center',
        'SC',
      ],
    ),
    _UniversityItem(
      name: 'Administration',
      nameAr: 'الإدارة',
      aliases: [
        'Administration',
        'Administrative Departments Building',
        'AD',
        'Presidential Building',
        'PR',
      ],
    ),
    _UniversityItem(
      name: 'Library',
      nameAr: 'المكتبة',
      aliases: [
        'Library',
      ],
    ),
  ];

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final locationsAsync =
        ref.watch(universityLocationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: locationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: _primaryBlue,
            ),
          ),
          error: (error, _) => _buildErrorState(error),
          data: (locations) {
            return Column(
              children: [
                Expanded(
                  child: _buildContent(
                    context,
                    locations,
                  ),
                ),

                // Shared animated bottom navigation
                const DroobiBottomNav(
                  currentItem: DroobiNavItem.university,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // CONTENT
  // ===========================================================================

  Widget _buildContent(
    BuildContext context,
    List<UniversityLocation> locations,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        16,
      ),
      children: [
        // -----------------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------------

        const Text(
          'Arab American University',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _textColor,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'الجامعة العربية الأمريكية',
          style: TextStyle(
            fontSize: 14,
            color: _secondaryText,
          ),
        ),

        const SizedBox(height: 28),

        // -----------------------------------------------------------------------
        // Colleges
        // -----------------------------------------------------------------------

        _buildSectionHeader(
          icon: Icons.school_outlined,
          title: 'COLLEGES',
        ),

        const SizedBox(height: 12),

        ..._colleges.map(
          (item) => Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ),
            child: _buildLocationCard(
              context: context,
              item: item,
              locations: locations,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // -----------------------------------------------------------------------
        // Gates
        // -----------------------------------------------------------------------

        _buildSectionHeader(
          icon: Icons.business_outlined,
          title: 'GATES',
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: _gates.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemBuilder: (
            context,
            index,
          ) {
            return _buildLocationCard(
              context: context,
              item: _gates[index],
              locations: locations,
              compact: true,
            );
          },
        ),

        const SizedBox(height: 28),

        // -----------------------------------------------------------------------
        // Facilities
        // -----------------------------------------------------------------------

        _buildSectionHeader(
          icon: Icons.local_cafe_outlined,
          title: 'FACILITIES',
        ),

        const SizedBox(height: 12),

        ..._facilities.map(
          (item) => Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ),
            child: _buildLocationCard(
              context: context,
              item: item,
              locations: locations,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION HEADER
  // ===========================================================================

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: _primaryBlue,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _secondaryText,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LOCATION CARD
  // ===========================================================================

  Widget _buildLocationCard({
    required BuildContext context,
    required _UniversityItem item,
    required List<UniversityLocation> locations,
    bool compact = false,
  }) {
    final location = _findLocation(
      item,
      locations,
    );

    final isAvailable = location != null;

    return Semantics(
      button: true,
      enabled: isAvailable,
      label: '${item.name}, ${item.nameAr}',
      hint: isAvailable
          ? 'Double tap to select this location.'
          : 'This location is not available yet.',
      child: Material(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(10),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(10),
          onTap: isAvailable
              ? () {
                  _handleLocationSelect(
                    context,
                    item,
                    location,
                  );
                }
              : () {
                  _showUnavailableMessage(
                    context,
                    item,
                  );
                },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 10 : 12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  maxLines: compact ? 1 : 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        compact ? 13 : 14,
                    fontWeight:
                        FontWeight.w500,
                    color: isAvailable
                        ? _textColor
                        : _textColor.withValues(
                            alpha: 0.55,
                          ),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  item.nameAr,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        compact ? 11 : 12,
                    color: isAvailable
                        ? _secondaryText
                        : _secondaryText.withValues(
                            alpha: 0.65,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FIND LOCATION
  // ===========================================================================

  UniversityLocation? _findLocation(
    _UniversityItem item,
    List<UniversityLocation> locations,
  ) {
    for (final location in locations) {
      final locationName =
          _normalize(location.name);

      for (final alias in item.aliases) {
        final normalizedAlias =
            _normalize(alias);

        if (locationName == normalizedAlias ||
            locationName.contains(
              normalizedAlias,
            ) ||
            normalizedAlias.contains(
              locationName,
            )) {
          return location;
        }
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[-_]+'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
  }

  // ===========================================================================
  // LOCATION SELECT
  // ===========================================================================

  void _handleLocationSelect(
    BuildContext context,
    _UniversityItem item,
    UniversityLocation location,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Selected ${item.name}',
          ),
        ),
      );

    // GPS + routing will be connected
    // in the GPS/routing stage.
    //
    // The selected coordinates are available:
    // location.latitude
    // location.longitude
  }

  // ===========================================================================
  // UNAVAILABLE LOCATION
  // ===========================================================================

  void _showUnavailableMessage(
    BuildContext context,
    _UniversityItem item,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${item.name} is not available yet.',
          ),
        ),
      );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    Object error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color:
                    Colors.grey.shade400,
              ),

              const SizedBox(height: 16),

              const Text(
                'Could not load university locations.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w500,
                  color: _textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                error.toString(),
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// UNIVERSITY ITEM
// ==============================================================================

class _UniversityItem {
  const _UniversityItem({
    required this.name,
    required this.nameAr,
    required this.aliases,
  });

  final String name;
  final String nameAr;
  final List<String> aliases;
}