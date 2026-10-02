package com.linkcat.wolody

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 안드로이드 햅틱. Flutter의 HapticFeedback은 안드로이드에서 View.performHapticFeedback의
 * CLOCK_TICK·KEYBOARD_TAP·VIRTUAL_KEY 같은 상수를 쓰는데, 삼성 등 많은 기기에서 이 상수는
 * 아주 약하거나 아예 울리지 않는다. 그래서 진동 모터에 직접 효과를 요청한다.
 *
 * iOS(wolody/haptics)와 같은 채널을 쓴다.
 * - impact: selection / light / medium / heavy
 * - notification: success / warning / error
 */
class HapticsBridge private constructor(context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "wolody/haptics"

        fun register(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL)
                .setMethodCallHandler(HapticsBridge(context.applicationContext))
        }
    }

    private val vibrator: Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val type = call.arguments as? String ?: ""
        when (call.method) {
            "impact" -> play(impact(type))
            "notification" -> play(notification(type))
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    private fun play(effect: VibrationEffect?) {
        val vibrator = vibrator ?: return
        if (effect == null || !vibrator.hasVibrator()) return
        vibrator.vibrate(effect)
    }

    /** 한 번 톡. 가능하면 기기가 튜닝해 둔 짧은 효과를 쓰고, 없으면 짧은 진동으로 흉내 낸다. */
    private fun impact(type: String): VibrationEffect? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val (primitive, scale) = when (type) {
                "selection" -> VibrationEffect.Composition.PRIMITIVE_TICK to 0.6f
                "light" -> VibrationEffect.Composition.PRIMITIVE_TICK to 1f
                "medium" -> VibrationEffect.Composition.PRIMITIVE_CLICK to 0.7f
                else -> VibrationEffect.Composition.PRIMITIVE_CLICK to 1f
            }
            if (vibrator?.areAllPrimitivesSupported(primitive) == true) {
                return VibrationEffect.startComposition().addPrimitive(primitive, scale).compose()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return VibrationEffect.createPredefined(
                when (type) {
                    "selection", "light" -> VibrationEffect.EFFECT_TICK
                    "medium" -> VibrationEffect.EFFECT_CLICK
                    else -> VibrationEffect.EFFECT_HEAVY_CLICK
                },
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val (millis, amplitude) = when (type) {
                "selection" -> 8L to 60
                "light" -> 10L to 90
                "medium" -> 15L to 150
                else -> 25L to 255
            }
            return VibrationEffect.createOneShot(millis, amplitude)
        }
        return null
    }

    /** iOS 알림 햅틱처럼 성공은 두 번, 경고는 두 번(약하게), 오류는 세 번 톡톡톡. */
    private fun notification(type: String): VibrationEffect? {
        val taps = when (type) {
            "error" -> 3
            else -> 2
        }
        val strength = if (type == "warning") 0.6f else 1f
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            vibrator?.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_CLICK) == true
        ) {
            val composition = VibrationEffect.startComposition()
            repeat(taps) { index ->
                composition.addPrimitive(
                    VibrationEffect.Composition.PRIMITIVE_CLICK,
                    strength,
                    if (index == 0) 0 else 70,
                )
            }
            return composition.compose()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // [진동 20ms, 쉼 70ms]를 횟수만큼 반복한다.
            val timings = LongArray(taps * 2) { if (it % 2 == 0) 20L else 70L }
            val amplitude = (255 * strength).toInt()
            val amplitudes = IntArray(taps * 2) { if (it % 2 == 0) amplitude else 0 }
            return VibrationEffect.createWaveform(timings, amplitudes, -1)
        }
        return null
    }
}
