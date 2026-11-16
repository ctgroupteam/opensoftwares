import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize Flutter Local Notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _onNotificationClick.add({'payload': payload, 'actionId': response.actionId});
        }
      },
    );

    // 2. Create Notification Channels
    const AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
      'alerts',
      'High Priority Alerts & Alarms',
      description: 'Used for urgent Quick Alerts with repeating alarm sound',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_alert'),
      enableVibration: true,
    );

    const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
      'reminders',
      'Reminders & Meetings',
      description: 'Scheduled reminders and meetings',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general',
      'General Updates',
      description: 'General tasks and updates',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(alertsChannel);
      await androidPlugin.createNotificationChannel(remindersChannel);
      await androidPlugin.createNotificationChannel(generalChannel);
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

  // Request Android 13+ Notification Permissions
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
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

  // Display Local Notification (Foreground or Data Message)
  static Future<void> showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? message.notification?.title ?? 'OpenSoftwares CRM';
    final body = data['body'] ?? message.notification?.body ?? 'New notification received';
    final type = data['type'] ?? 'general';
    final bool requireAck = data['require_ack'] == 'true';

    // Channel selection
    String channelId = 'general';
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;
    AndroidNotificationDetails androidDetails;

    if (type == 'alerts' || requireAck) {
      channelId = 'alerts';
      importance = Importance.max;
      priority = Priority.max;

      // 0x04 flag represents FLAG_INSISTENT (keeps ringing until dismissed/opened)
      androidDetails = AndroidNotificationDetails(
        channelId,
        'High Priority Alerts & Alarms',
        importance: importance,
        priority: priority,
        sound: const RawResourceAndroidNotificationSound('alarm_alert'),
        playSound: true,
        enableVibration: true,
        additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4
        actions: const [
          AndroidNotificationAction('action_seen', 'Seen', showsUserInterface: true),
          AndroidNotificationAction('action_snooze', 'Snooze', showsUserInterface: false),
        ],
      );
    } else if (type == 'reminders' || type == 'meeting') {
      channelId = 'reminders';
      importance = Importance.high;
      priority = Priority.high;
      androidDetails = AndroidNotificationDetails(
        channelId,
        'Reminders & Meetings',
        importance: importance,
        priority: priority,
        playSound: true,
        enableVibration: true,
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        channelId,
        'General Updates',
        importance: importance,
        priority: priority,
        playSound: true,
      );
    }

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      notificationId,
      title,
      body,
      platformDetails,
      payload: data['click_action'] ?? data['target_screen'] ?? 'home',
    );
  }
}
