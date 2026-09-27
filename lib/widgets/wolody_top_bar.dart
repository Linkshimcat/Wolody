import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'glass_back_button.dart';

/// 보조 화면 상단: 유리 뒤로 가기 버튼 + 제목 (+ 오른쪽 동작).
class WolodyTopBar extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const WolodyTopBar({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
      child: Row(
        children: [
          GlassBackButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.maybePop(context);
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
