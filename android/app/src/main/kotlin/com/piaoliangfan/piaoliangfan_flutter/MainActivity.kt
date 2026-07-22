package com.piaoliangfan.piaoliangfan_flutter

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "piaoliangfan/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "share" -> {
                        val imagePath = call.argument<String>("imagePath")
                        val text = call.argument<String>("text") ?: ""
                        if (imagePath == null) {
                            result.error("INVALID_ARGS", "imagePath is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(imagePath)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "image not found: $imagePath", null)
                                return@setMethodCallHandler
                            }
                            // why: Android 7+ 强制 content:// URI 不能传 file:// —— FileProvider 转
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_TEXT, text)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val chooser = Intent.createChooser(sendIntent, "分享漂亮饭")
                            startActivity(chooser)
                            result.success("shared")
                        } catch (e: Exception) {
                            result.error("SHARE_FAIL", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}