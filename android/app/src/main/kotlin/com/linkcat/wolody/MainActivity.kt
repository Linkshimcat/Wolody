package com.linkcat.wolody

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 설정 → 실시간 화면에 표시: 안드로이드는 Live Update(진행 중 알림)로 보여 준다.
        LiveUpdateBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
        // 기본 HapticFeedback이 많은 기기에서 울리지 않아 진동 모터에 직접 요청한다.
        HapticsBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
