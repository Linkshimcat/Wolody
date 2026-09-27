import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/wolody_top_bar.dart';

/// 설정 → 오픈소스 라이선스. 앱에 들어간 패키지와 폰트의 라이선스를 모아 보여준다.
///
/// Flutter가 패키지 라이선스를 [LicenseRegistry]에 자동으로 모아 두고,
/// 폰트(BM Jua OFL)처럼 직접 넣은 것은 main.dart에서 추가 등록한다.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  /// 패키지 이름 → 그 패키지의 라이선스 문단 묶음들.
  Map<String, List<List<LicenseParagraph>>>? _byPackage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final byPackage = <String, List<List<LicenseParagraph>>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final paragraphs = entry.paragraphs.toList();
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(paragraphs);
      }
    }
    if (mounted) setState(() => _byPackage = byPackage);
  }

  @override
  Widget build(BuildContext context) {
    final byPackage = _byPackage;
    final packages = byPackage?.keys.toList()
      ?..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const WolodyTopBar(title: '오픈소스 라이선스'),
            Expanded(
              child: packages == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        20,
                        24,
                        kBottomNavSpace,
                      ),
                      itemCount: packages.length + 1,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: index == 0 ? 20 : 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Text(
                            'Wolody는 아래 오픈소스 소프트웨어와 폰트로 만들어졌어요. '
                            '항목을 누르면 라이선스 전문을 볼 수 있어요. '
                            '(${packages.length}개)',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: WolodyColors.textSecondary,
                            ),
                          );
                        }
                        final package = packages[index - 1];
                        final licenses = byPackage![package]!;
                        return _PackageRow(
                          name: package,
                          count: licenses.length,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => _LicenseDetailScreen(
                                  package: package,
                                  licenses: licenses,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const _PackageRow({
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: WolodyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (count > 1)
              Text(
                '라이선스 $count개',
                style: const TextStyle(
                  fontSize: 12,
                  color: WolodyColors.textSecondary,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LicenseDetailScreen extends StatelessWidget {
  final String package;
  final List<List<LicenseParagraph>> licenses;

  const _LicenseDetailScreen({required this.package, required this.licenses});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WolodyTopBar(title: package),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, kBottomNavSpace),
                children: [
                  for (var i = 0; i < licenses.length; i++) ...[
                    if (i > 0)
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        color: WolodyColors.outline,
                      ),
                    for (final paragraph in licenses[i])
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 10,
                          left:
                              paragraph.indent ==
                                  LicenseParagraph.centeredIndent
                              ? 0
                              : paragraph.indent * 16.0,
                        ),
                        child: Text(
                          paragraph.text,
                          textAlign:
                              paragraph.indent ==
                                  LicenseParagraph.centeredIndent
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFFC9CDD4),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
