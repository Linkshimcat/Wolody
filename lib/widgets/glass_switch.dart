import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// iOS 26에서는 네이티브 Liquid Glass 스타일의 UISwitch를, 그 밖의
/// 플랫폼에서는 CupertinoSwitch로 대체한 토글.
class GlassSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const GlassSwitch({super.key, required this.value, this.onChanged});

  @override
  State<GlassSwitch> createState() => _GlassSwitchState();
}

class _GlassSwitchState extends State<GlassSwitch> {
  // 스위치마다 별도 채널을 써야 상태를 서로 섞지 않는다.
  static int _channelSequence = 0;
  late final MethodChannel _channel = MethodChannel(
    'wolody/glass_switch_${_channelSequence++}',
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      final value = (call.arguments as Map?)?['value'] as bool? ?? false;
      widget.onChanged?.call(value);
    }
    return null;
  }

  @override
  void didUpdateWidget(GlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 알림 권한 거절처럼 화면 상태가 도로 돌아가도 네이티브 스위치가 어긋나지
    // 않도록 리빌드할 때마다 최신 값을 밀어 넣는다.
    _channel.invokeMethod<void>('setValue', {'value': widget.value});
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return CupertinoSwitch(value: widget.value, onChanged: widget.onChanged);
    }
    return SizedBox(
      // iOS 26 UISwitch(63pt)까지 담는 크기. 네이티브 쪽에서 오른쪽 끝에 맞추므로
      // 폭이 더 좁은 예전 스위치도 오른쪽 여백이 똑같이 유지된다.
      width: 64,
      height: 31,
      child: UiKitView(
        viewType: 'wolody/glass_switch',
        creationParams: {
          'value': widget.value,
          'channelName': _channel.name,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
