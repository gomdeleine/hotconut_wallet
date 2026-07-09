package app.hotconut.wallet

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "app.hotconut.wallet/os"
    private val CHANNEL_OPEN_APP_SETTINGS = "app-settings"
    private var osChannel: MethodChannel? = null
    private var pendingBitcoinUri: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        osChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        pendingBitcoinUri = extractBitcoinUri(intent)

        osChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getPlatformVersion") {
                val version = Build.VERSION.RELEASE
                result.success(version)
            } else if(call.method == "getSdkVersion"){
                result.success(Build.VERSION.SDK_INT)
            } else if(call.method == "getInitialBitcoinUri" || call.method == "getPendingBitcoinUri"){
                result.success(pendingBitcoinUri)
                pendingBitcoinUri = null
            } else if(call.method == "setSecureFlag"){
                val enabled = call.argument<Boolean>("enabled") ?: false
                runOnUiThread {
                    if (enabled) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            }
            else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OPEN_APP_SETTINGS).setMethodCallHandler { call, result ->
            if (call.method == "openAppSettings") {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:" + applicationContext.packageName)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val bitcoinUri = extractBitcoinUri(intent) ?: return
        pendingBitcoinUri = bitcoinUri
        osChannel?.invokeMethod("onBitcoinUri", bitcoinUri)
    }

    private fun extractBitcoinUri(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null

        val dataString = intent.dataString ?: return null
        return if (dataString.startsWith("bitcoin:", ignoreCase = true)) {
            dataString
        } else {
            null
        }
    }
}
