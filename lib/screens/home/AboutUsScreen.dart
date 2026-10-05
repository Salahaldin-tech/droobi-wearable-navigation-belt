import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const _repoUrl =
      'https://github.com/Salahaldin-tech/droobi-wearable-navigation-belt';

  static const _blue = Color(0xFF2F80ED);

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final s = ar ? _L.ar : _L.en;
    final base = Theme.of(context);
    final cs = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: base.brightness,
    ).copyWith(primary: _blue, onPrimary: Colors.white);
    final tt = base.textTheme;

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Theme(
        data: base.copyWith(colorScheme: cs),
        child: Scaffold(
          appBar: AppBar(title: Text(s.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // ---------- Header ----------
              Center(
                child: Column(
                  children: [
                    Image.asset( 'assets/images/app_logo.png', height: 96),

                    const SizedBox(height: 16),
                    Text('Droobi',
                        style: tt.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(s.tagline,
                        textAlign: TextAlign.center,
                        style: tt.titleMedium?.copyWith(color: cs.primary)),
                    const SizedBox(height: 8),
                    Chip(label: Text('${s.version} 1.0.0')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(s.description, style: tt.bodyLarge?.copyWith(height: 1.5)),

              // ---------- Features ----------
              _Section(s.featuresTitle),
              ...s.features.map((f) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(f.icon, color: cs.primary),
                      title: Text(f.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(f.body),
                    ),
                  )),

              // ---------- Team ----------
              _Section(s.teamTitle),
              ..._members.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: cs.secondaryContainer,
                              child: Text(m.initials,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSecondaryContainer)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: tt.titleMedium),
                                const SizedBox(height: 2),
                                Text(s.memberRole,
                                    style: tt.bodyMedium
                                        ?.copyWith(color: cs.primary)),
                                const SizedBox(height: 6),
                                Text(s.memberBio, style: tt.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),

              // ---------- Academic info ----------
              _Section(s.academicTitle),
              Card(
                child: Column(
                  children: [
                    _InfoTile(Icons.school, s.university, s.universityValue),
                    _InfoTile(Icons.apartment, s.faculty, s.facultyValue),
                    _InfoTile(Icons.memory, s.department, s.departmentValue),
                    _InfoTile(Icons.assignment, s.project, s.projectValue),
                    _InfoTile(
                        Icons.person_pin, s.supervisor, s.supervisorValue),
                    _InfoTile(Icons.calendar_month, s.year, '2026/2027'),
                  ],
                ),
              ),

              // ---------- Acknowledgments ----------
              _Section(s.ackTitle),
              Text(s.ackBody, style: tt.bodyLarge?.copyWith(height: 1.5)),

              // ---------- GitHub ----------
              const SizedBox(height: 24),
              Center(
                child: FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(_repoUrl),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.code),
                  label: Text(s.github),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- helpers ----------------

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Semantics(
          header: true,
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w500)),
      );
}

// ---------------- data ----------------

class _Member {
  final String name, initials;
  const _Member(this.name, this.initials);
}

const _members = [
  _Member('Salahaldin Almughayyar', 'SA'),
  _Member('Mostfa Elhaj Mahmoud', 'ME'),
  _Member('Wesam Khairallah', 'WK'),
];

class _Feature {
  final IconData icon;
  final String title, body;
  const _Feature(this.icon, this.title, this.body);
}

class _L {
  final String title, tagline, version, description, featuresTitle, teamTitle,
      memberRole, memberBio, academicTitle, university, universityValue,
      faculty, facultyValue, department, departmentValue, project,
      projectValue, supervisor, supervisorValue, year, ackTitle, ackBody,
      github;
  final List<_Feature> features;

  const _L({
    required this.title,
    required this.tagline,
    required this.version,
    required this.description,
    required this.featuresTitle,
    required this.features,
    required this.teamTitle,
    required this.memberRole,
    required this.memberBio,
    required this.academicTitle,
    required this.university,
    required this.universityValue,
    required this.faculty,
    required this.facultyValue,
    required this.department,
    required this.departmentValue,
    required this.project,
    required this.projectValue,
    required this.supervisor,
    required this.supervisorValue,
    required this.year,
    required this.ackTitle,
    required this.ackBody,
    required this.github,
  });

  static const en = _L(
    title: 'About Us',
    tagline: 'Navigation belt for visually impaired people',
    version: 'Version',
    description:
        'Droobi is a navigation application designed to help visually impaired '
        'users navigate their surroundings more independently and confidently. '
        'It combines GPS, digital maps, route guidance, voice interaction, and '
        'a wearable navigation belt that provides directional feedback through '
        'vibration.',
    featuresTitle: 'Key Features',
    features: [
      _Feature(Icons.alt_route, 'Smart Route Navigation',
          'Calculates and tracks routes using GPS.'),
      _Feature(Icons.mic, 'Voice Interaction',
          'Supports Arabic and English voice commands.'),
      _Feature(Icons.vibration, 'Wearable Navigation Belt',
          'Directional vibration feedback through an ESP32-based belt.'),
      _Feature(Icons.favorite, 'Favorites',
          'Save frequently visited locations.'),
      _Feature(Icons.accessibility_new, 'Accessible Interface',
          'Designed for accessibility and simple interaction.'),
    ],
    teamTitle: 'The Team',
    memberRole: '',
    memberBio:
        ' '
        ,
    academicTitle: 'Academic Information',
    university: 'University',
    universityValue: 'Arab American University (AAUP)',
    faculty: 'Faculty',
    facultyValue: 'Faculty of Engineering',
    department: 'Department',
    departmentValue: 'Computer Engineering',
    project: 'Project',
    projectValue: 'Navigation Belt for Visually Impaired People',
    supervisor: 'Supervisor',
    supervisorValue: 'Prof. Osama Izzat Yaqoub Salameh',
    year: 'Academic Year',
    ackTitle: 'Acknowledgments',
    ackBody:
        'We would like to express our sincere gratitude to the Arab American '
        'University, Faculty of Engineering, our supervisor, and everyone who '
        'supported us throughout the development of the Droobi project. Their '
        'guidance, support, and feedback contributed significantly to the '
        'development of this project.',
    github: 'View on GitHub',
  );

  static const ar = _L(
    title: 'من نحن',
    tagline: 'تنقّل ذكي نحو رحلة أكثر استقلالية',
    version: 'الإصدار',
    description:
        'دروبي تطبيق ملاحة صُمّم لمساعدة المكفوفين وضعاف البصر على التنقل في '
        'محيطهم بشكل أكثر استقلالية وثقة. يجمع التطبيق بين نظام GPS والخرائط '
        'الرقمية وإرشاد المسار والتفاعل الصوتي، إضافةً إلى حزام ملاحة قابل '
        'للارتداء يعطي إشارات الاتجاه عبر الاهتزاز.',
    featuresTitle: 'المزايا الرئيسية',
    features: [
      _Feature(Icons.alt_route, 'ملاحة ذكية للمسار',
          'يحسب المسارات ويتتبعها باستخدام GPS.'),
      _Feature(Icons.mic, 'التفاعل الصوتي',
          'يدعم الأوامر الصوتية بالعربية والإنجليزية.'),
      _Feature(Icons.vibration, 'حزام الملاحة القابل للارتداء',
          'إشارات اتجاه عبر الاهتزاز من خلال حزام يعتمد على ESP32.'),
      _Feature(Icons.favorite, 'المفضلة',
          'احفظ الأماكن التي تزورها باستمرار.'),
      _Feature(Icons.accessibility_new, 'واجهة سهلة الوصول',
          'مصممة بما يراعي إمكانية الوصول وبساطة الاستخدام.'),
    ],
    teamTitle: 'فريق العمل',
    memberRole: 'مطوّر برمجيات / تطبيقات',
    memberBio:
        'يساهم في تطوير البرمجيات ووظائف التطبيق وتكامل أجزاء نظام دروبي.',
    academicTitle: 'المعلومات الأكاديمية',
    university: 'الجامعة',
    universityValue: 'الجامعة العربية الأمريكية',
    faculty: 'الكلية',
    facultyValue: 'كلية الهندسة',
    department: 'القسم',
    departmentValue: 'هندسة الحاسوب',
    project: 'المشروع',
    projectValue: 'حزام الملاحة للمكفوفين وضعاف البصر',
    supervisor: 'المشرف',
    supervisorValue: 'أ.د. أسامة عزت يعقوب سلامة',
    year: 'العام الدراسي',
    ackTitle: 'شكر وتقدير',
    ackBody:
        'نتقدم بخالص الشكر والامتنان إلى الجامعة العربية الأمريكية وكلية '
        'الهندسة ومشرفنا وكل من دعمنا خلال تطوير مشروع دروبي. لقد أسهمت '
        'توجيهاتهم ودعمهم وملاحظاتهم إسهامًا كبيرًا في إنجاز هذا المشروع.',
    github: 'عرض على GitHub',
  );
}