import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Top-level entry point for background FCM messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.showLocalNotification(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static final StreamController<Map<String, dynamic>> _onNotificationClick =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onNotificationClick =>
      _onNotificationClick.stream;

  // 5 High-Quality Clean Notification Sounds (Alarm tone removed, single unified choice)
  static const String defaultSound = 'sound_reminder';
  static const String _prefSoundKey = 'preferred_notification_sound';

  static const Map<String, String> availableSounds = {
    'sound_reminder': 'Reminder Chime (Default)',
    'sound_meeting': 'Meeting Triad Chord',
    'sound_task': 'Task Double Pop',
    'sound_notice': 'Notice Harmonics',
    'sound_pulse': 'Executive Pulse',
  };

  // Get currently selected notification sound (persisted in SharedPreferences)
  Future<String> getSelectedSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefSoundKey) ?? defaultSound;
    } catch (_) {
      return defaultSound;
    }
  }

  // Set user preferred notification sound for all notifications
  Future<void> setSelectedSound(String soundKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSoundKey, soundKey);
    } catch (_) {}
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Android & iOS Initialization Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _onNotificationClick.add({'payload': payload, 'actionId': response.actionId});
        }
      },
    );

    // 2. Create High-Priority Channels for all 5 Clean Sounds
    try {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        for (final entry in availableSounds.entries) {
          final channel = AndroidNotificationChannel(
            'channel_${entry.key}',
            'CRM: ${entry.value}',
            description: 'Notification sound: ${entry.value}',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            sound: RawResourceAndroidNotificationSound(entry.key),
          );
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    } catch (e) {
      debugPrint('Notification channel creation error: $e');
    }

    // 3. Setup Firebase Messaging Listeners
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onNotificationClick.add(message.data);
    });

    // 4. Token Refresh Listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveDeviceToken(newToken);
    });

    _isInitialized = true;
  }

  // Request Android 13+ Notification Permissions (triggers native prompt)
  Future<bool> requestPermission() async {
    try {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted = await androidPlugin?.requestNotificationsPermission();

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return androidGranted == true ||
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  // Show immediate Heads-Up Pop-Up Banner on Screen with user's chosen notification sound
  Future<void> showHeadsUpNotification({
    required String title,
    required String body,
    String? type,
    String? overrideSound,
    String? payload,
  }) async {
    final sound = overrideSound ?? await getSelectedSound();
    final soundLabel = availableSounds[sound] ?? 'Notification';

    final androidDetails = AndroidNotificationDetails(
      'channel_$sound',
      'CRM: $soundLabel',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: title,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
      enableVibration: true,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload ?? 'home',
    );
  }

  // Test and preview any of the 5 custom sounds as on-screen heads-up notification
  Future<void> sendTestNotification(String soundKey) async {
    final soundName = availableSounds[soundKey] ?? 'Notification Sound';
    await showHeadsUpNotification(
      title: 'Sound Preview: $soundName',
      body: 'Heads-up notification with $soundName popped up on screen',
      overrideSound: soundKey,
      payload: 'home',
    );
  }

  // Save FCM Token to crm_notifications table for current user
  Future<void> syncDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await saveDeviceToken(token);
      }
    } catch (_) {}
  }

  static Future<void> saveDeviceToken(String token) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('crm_notifications').upsert(
        {
          'user_id': userId,
          'device_token': token,
          'platform': 'android',
          'notification_type': 'general',
        },
        onConflict: 'user_id,device_token',
      );
    } catch (_) {}
  }

  // Display Local Heads-Up Banner Notification for Foreground or Data FCM Messages
  static Future<void> showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title ?? 'OpenSoftwares CRM';
    final body = data['body'] ?? message.notification?.body ?? 'New update received';

    final sound = await instance.getSelectedSound();
    final soundLabel = availableSounds[sound] ?? 'Notification';

    final androidDetails = AndroidNotificationDetails(
      'channel_$sound',
      'CRM: $soundLabel',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: title,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: data['click_action'] ?? data['target_screen'] ?? 'home',
    );
  }
}
