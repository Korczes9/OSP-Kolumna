package pl.ospkolumna.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import kotlinx.coroutines.*
import java.util.Date

class RealtimeService : Service() {

    private val TAG = "RealtimeService"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "realtime_service_channel"
    
    private var serviceJob: Job? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Firebase Firestore
    private val firestore = FirebaseFirestore.getInstance()
    private var alarmsListener: ListenerRegistration? = null
    private val processedAlarms = mutableSetOf<String>()
    
    companion object {
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Serwis utworzony")
        createNotificationChannel()
        createAlarmNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Serwis uruchomiony")
        
        // Uruchom serwis jako Foreground Service
        startForeground(NOTIFICATION_ID, createNotification("Czuwanie"))
        isRunning = true
        
        // Uruchom nasłuchiwanie Firebase
        startFirebaseListener()
        
        return START_STICKY
    }

    private fun startFirebaseListener() {
        Log.d(TAG, "🔥 Uruchamianie Firebase Listener...")
        
        // Nasłuchuj nowych powiadomień z Discord (słowo kluczowe KOLUMNA)
        alarmsListener = firestore.collection("powiadomienia")
            .orderBy("utworzonoO", Query.Direction.DESCENDING)
            .limit(10)
            .addSnapshotListener { snapshots, error ->
                if (error != null) {
                    Log.e(TAG, "❌ Błąd Firebase Listener: ${error.message}")
                    updateNotification("Błąd: ${error.message}")
                    return@addSnapshotListener
                }

                if (snapshots != null && !snapshots.isEmpty) {
                    for (docChange in snapshots.documentChanges) {
                        when (docChange.type) {
                            com.google.firebase.firestore.DocumentChange.Type.ADDED -> {
                                val doc = docChange.document
                                val alarmId = doc.id
                                
                                // Sprawdź czy już przetworzony
                                if (processedAlarms.contains(alarmId)) {
                                    continue
                                }
                                
                                // Pobierz dane powiadomienia
                                val type = doc.getString("data.type") ?: doc.getString("type") ?: ""
                                val title = doc.getString("title") ?: "Powiadomienie"
                                val body = doc.getString("body") ?: ""
                                val fullContent = doc.getString("data.fullContent") ?: body
                                
                                // Sprawdź czy to ALARM (wykryte słowo KOLUMNA na Discord)
                                if (type == "ALARM") {
                                    // Sprawdź czy alarm jest świeży (ostatnie 2 minuty)
                                    val utworzonoO = doc.getTimestamp("utworzonoO")
                                    if (utworzonoO != null) {
                                        val alarmTime = utworzonoO.toDate()
                                        val now = Date()
                                        val diffMinutes = (now.time - alarmTime.time) / 1000 / 60
                                        
                                        if (diffMinutes <= 2) {
                                            // NOWY ALARM !
                                            Log.d(TAG, "🚨 NOWY ALARM ! ID: $alarmId")
                                            Log.d(TAG, "   Tytuł: $title")
                                            Log.d(TAG, "   Treść: $fullContent")
                                            
                                            // Oznacz jako przetworzony
                                            processedAlarms.add(alarmId)
                                            
                                            // Wyświetl pełnoekranowy alarm
                                            showFullScreenAlarm(alarmId, fullContent, "Discord - Słowo kluczowe: KOLUMNA")
                                            
                                            // Aktualizuj powiadomienie serwisu
                                            updateNotification("Ostatni alarm: Discord")
                                        }
                                    }
                                }
                            }
                            else -> {
                                // Ignoruj modyfikacje i usunięcia
                            }
                        }
                    }
                }
            }
        
        Log.d(TAG, "✅ OSP Kolumna- czuwanie")
    }

    private fun showFullScreenAlarm(alarmId: String, lokalizacja: String, opis: String) {
        Log.d(TAG, "📱 Wyświetlam pełnoekranowy alarm...")
        
        val alarmIntent = Intent(this, AlarmActivity::class.java).apply {
            putExtra(AlarmActivity.EXTRA_ALARM_TITLE, "🚨 ALARM!")
            putExtra(AlarmActivity.EXTRA_ALARM_MESSAGE, lokalizacja)
            putExtra(AlarmActivity.EXTRA_ALARM_ID, alarmId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ - użyj Full Screen Intent przez powiadomienie
            val fullScreenPendingIntent = PendingIntent.getActivity(
                this,
                alarmId.hashCode(),
                alarmIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            
            val alarmNotification = NotificationCompat.Builder(this, "alarm_channel")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("🚨 ALARM!")
                .setContentText(lokalizacja)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setFullScreenIntent(fullScreenPendingIntent, true)
                .build()
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(alarmId.hashCode(), alarmNotification)
        } else {
            // Android 9 i niższe - uruchom bezpośrednio
            startActivity(alarmIntent)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Serwis czasu rzeczywistego",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Powiadomienia serwisu działającego w tle"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createAlarmNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "alarm_channel",
                "Alarmy strażackie",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Powiadomienia o nowych alarmach"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(contentText: String): Notification {
        // Intent do otwarcia aplikacji po kliknięciu w powiadomienie
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OSP Kolumna - Działanie w tle")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // Nie można ręcznie usunąć
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val notification = createNotification(contentText)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        Log.d(TAG, "Serwis zatrzymany")
        isRunning = false
        alarmsListener?.remove()
        serviceJob?.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
