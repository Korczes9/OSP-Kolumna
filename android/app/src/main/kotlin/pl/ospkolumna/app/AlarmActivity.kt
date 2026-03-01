package pl.ospkolumna.app

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.view.Gravity
import android.widget.LinearLayout

/**
 * Pełnoekranowa aktywność alarmu wyświetlana nawet na zablokowanym ekranie
 */
class AlarmActivity : AppCompatActivity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    companion object {
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_MESSAGE = "alarm_message"
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Włącz ekran nawet gdy telefon jest zablokowany
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOnFlags()
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        // Pobierz dane z Intent
        val title = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "ALARM!"
        val message = intent.getStringExtra(EXTRA_ALARM_MESSAGE) ?: "Nowy wyjazd strażacki"
        val alarmId = intent.getStringExtra(EXTRA_ALARM_ID) ?: ""

        // Utwórz UI programatowo (bez XML)
        createAlarmUI(title, message, alarmId)

        // Odtwórz dźwięk alarmu
        playAlarmSound()

        // Wibruj
        startVibration()
    }

    private fun setTurnScreenOnFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }
        
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun createAlarmUI(title: String, message: String, alarmId: String) {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#D32F2F"))
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }

        // Ikona alarmu (emoji)
        val iconText = TextView(this).apply {
            text = "🚨"
            textSize = 80f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }
        layout.addView(iconText)

        // Tytuł
        val titleText = TextView(this).apply {
            text = title
            textSize = 32f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(16, 0, 16, 16)
        }
        layout.addView(titleText)

        // Wiadomość
        val messageText = TextView(this).apply {
            text = message
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(16, 0, 16, 48)
        }
        layout.addView(messageText)

        // Przycisk "OTWIERAM APLIKACJĘ"
        val openButton = Button(this).apply {
            text = "OTWIERAM APLIKACJĘ"
            textSize = 18f
            setBackgroundColor(Color.parseColor("#FFEB3B"))
            setTextColor(Color.parseColor("#D32F2F"))
            setPadding(48, 32, 48, 32)
            setOnClickListener {
                stopAlarmAndOpenApp()
            }
        }
        
        val buttonParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            setMargins(32, 16, 32, 16)
        }
        layout.addView(openButton, buttonParams)

        // Przycisk "ZAMKNIJ ALARM"
        val dismissButton = Button(this).apply {
            text = "ZAMKNIJ ALARM"
            textSize = 16f
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.WHITE)
            setPadding(48, 24, 48, 24)
            setOnClickListener {
                stopAlarmAndDismiss()
            }
        }
        
        layout.addView(dismissButton, buttonParams)

        setContentView(layout)
    }

    private fun playAlarmSound() {
        try {
            mediaPlayer = MediaPlayer().apply {
                // Użyj własnego dźwięku syreny z res/raw/syrena_2.mp3
                val afd = resources.openRawResourceFd(resources.getIdentifier(
                    "syrena_2",
                    "raw",
                    packageName
                ))
                
                if (afd != null) {
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } else {
                    // Fallback do systemowego dźwięku jeśli nie znajdzie pliku
                    val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    setDataSource(applicationContext, alarmUri)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                }
                
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 500, 500, 500, 500, 500)
            vibrator?.vibrate(
                VibrationEffect.createWaveform(pattern, 0)
            )
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, 500, 500, 500, 500, 500)
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopAlarmAndOpenApp() {
        stopAlarm()
        
        // Otwórz główną aplikację
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
        
        finish()
    }

    private fun stopAlarmAndDismiss() {
        stopAlarm()
        finish()
    }

    private fun stopAlarm() {
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            release()
        }
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    override fun onBackPressed() {
        // Wyłącz przycisk wstecz - użytkownik musi potwierdzić
        // super.onBackPressed()
    }
}
