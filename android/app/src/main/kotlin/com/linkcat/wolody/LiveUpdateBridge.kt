package com.linkcat.wolody

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * iOS LiveActivityBridge의 안드로이드 짝. 같은 채널(wolody/live_activity)과 같은 데이터로
 * 오늘의 마음 기록 상태를 알림으로 띄운다.
 *
 * Android 16 이상에서는 Live Update(승격된 진행 중 알림)로 요청해 상태 바 칩·잠금화면·
 * 알림창 맨 위에 고정되고, 그보다 낮은 버전에서는 일반 진행 중 알림으로 보인다.
 */
class LiveUpdateBridge private constructor(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "wolody/live_activity"
        private const val NOTIFICATION_CHANNEL_ID = "live_update"
        private const val NOTIFICATION_ID = 7001

        /** compileSdk 36에는 setRequestPromotedOngoing이 없어 extras로 직접 요청한다. */
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

        private const val EMOTION_SPRITE = "assets/AssetsDesign/EmotionAssets.png"
        private const val SPRITE_COLUMNS = 4
        private const val SPRITE_ROWS = 3

        /** 기록 전에 보여 줄 기본 표정(보통). */
        private const val DEFAULT_FACE = 4
        private const val BRAND_BLUE = 0xFF346AE6.toInt()

        fun register(context: Context, messenger: BinaryMessenger) {
            val bridge = LiveUpdateBridge(context.applicationContext)
            bridge.createChannel()
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(bridge)
        }
    }

    private val manager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "canPromote" -> result.success(canPromote())
            "openPromotionSettings" -> {
                openPromotionSettings()
                result.success(null)
            }
            "start", "update" -> {
                // iOS처럼 update는 이미 떠 있을 때만 내용을 바꾼다. 설정에서 켜지 않았는데
                // 기록할 때마다 알림이 새로 뜨면 안 된다.
                if (call.method == "update" &&
                    manager.activeNotifications.none { it.id == NOTIFICATION_ID }
                ) {
                    return result.success(false)
                }
                try {
                    manager.notify(NOTIFICATION_ID, build(call.arguments as? Map<*, *>))
                    result.success(true)
                } catch (e: SecurityException) {
                    // Android 13 이상에서 알림 권한이 없으면 띄울 수 없다.
                    result.error("not_enabled", e.message, null)
                }
            }
            "end" -> {
                manager.cancel(NOTIFICATION_ID)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun canPromote(): Boolean =
        Build.VERSION.SDK_INT >= 36 && manager.canPostPromotedNotifications()

    /** 이 앱의 Live Update 허용 화면. 없는 기기에서는 앱 알림 설정을 연다. */
    private fun openPromotionSettings() {
        val intent = if (Build.VERSION.SDK_INT >= 36) {
            Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS)
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        }
        intent.putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // Live Update는 MIN 중요도 채널을 승격하지 않는다. 대신 채널의 소리·진동을 끄고
        // 알림마다 setOnlyAlertOnce로 갱신할 때 다시 울리지 않게 한다.
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "오늘의 마음 실시간 표시",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "오늘 마음을 기록했는지 상태 바와 잠금화면에 계속 보여줍니다"
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun build(args: Map<*, *>?): Notification {
        val title = args?.get("title") as? String ?: "오늘의 마음"
        val label = args?.get("label") as? String ?: ""
        val recorded = args?.get("recorded") as? Boolean ?: false
        val face = (args?.get("face") as? Number)?.toInt() ?: DEFAULT_FACE

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_wolody)
            .setColor(BRAND_BLUE)
            .setContentTitle(title)
            .setContentText(if (recorded) label else "아직 기록하지 않았어요")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(openAppIntent())
            .addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
        // 상태 바 칩에 보이는 짧은 글자. iOS 다이나믹 아일랜드의 체크·연필 아이콘 자리다.
        if (Build.VERSION.SDK_INT >= 36) {
            builder.setShortCriticalText(if (recorded) "기록 완료" else "기록하기")
        }
        faceBitmap(face)?.let { builder.setLargeIcon(it) }
        return builder.build()
    }

    private fun openAppIntent(): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /** 감정 스프라이트(4열×3행)에서 [face]번 울디 얼굴을 잘라 동그랗게 만든다. */
    private fun faceBitmap(face: Int): Bitmap? = try {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(EMOTION_SPRITE)
        val sprite = context.assets.open(key).use { BitmapFactory.decodeStream(it) }
        val index = face.coerceIn(0, SPRITE_COLUMNS * SPRITE_ROWS - 1)
        val cellWidth = sprite.width / SPRITE_COLUMNS
        val cellHeight = sprite.height / SPRITE_ROWS
        val left = (index % SPRITE_COLUMNS) * cellWidth
        val top = (index / SPRITE_COLUMNS) * cellHeight
        val size = 192
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(output).apply {
            clipPath(Path().apply { addOval(RectF(0f, 0f, size.toFloat(), size.toFloat()), Path.Direction.CW) })
            drawColor(0xFFE9ECF3.toInt())
            drawBitmap(
                sprite,
                Rect(left, top, left + cellWidth, top + cellHeight),
                Rect(0, 0, size, size),
                Paint(Paint.FILTER_BITMAP_FLAG),
            )
        }
        sprite.recycle()
        output
    } catch (_: Exception) {
        null
    }
}
