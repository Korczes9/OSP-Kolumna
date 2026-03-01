package pl.ospkolumna.app

import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "pl.ospkolumna.app/realtime_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startRealtimeService()
                    result.success(true)
                }
                "stopService" -> {
                    stopRealtimeService()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(RealtimeService.isRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startRealtimeService() {
        val serviceIntent = Intent(this, RealtimeService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun stopRealtimeService() {
        val serviceIntent = Intent(this, RealtimeService::class.java)
        stopService(serviceIntent)
    }
}
