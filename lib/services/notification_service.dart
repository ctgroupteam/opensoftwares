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

    // 2. Create 5 Dedicated Notification Channels with 5 Distinct Custom Sounds
    try {
      const AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
        'alerts',
        'Urgent Quick Alerts',
        description: 'Urgent alarm broadcasts with repeating siren',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('alarm_alert'),
      );

      const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
        'reminders',
        'Reminders & Follow-ups',
        description: 'Scheduled reminders with crisp chime tone',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('sound_reminder'),
      );

      const AndroidNotificationChannel meetingsChannel = AndroidNotificationChannel(
        'meetings',
        'Meetings & Syncs',
        description: 'Meeting sync alerts with harmonic triad bell',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('sound_meeting'),
      );

      const AndroidNotificationChannel tasksChannel = AndroidNotificationChannel(
        'tasks',
        'Task Assignments',
        description: 'Task assignments and updates with modern pop chord',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('sound_task'),
      );

      const AndroidNotificationChannel noticesChannel = AndroidNotificationChannel(
        'general',
        'Notice Board & Announcements',
        description: 'Company broadcasts with crystal bell chime',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('sound_notice'),
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(alertsChannel);
        await androidPlugin.createNotificationChannel(remindersChannel);
        await androidPlugin.createNotificationChannel(meetingsChannel);
        await androidPlugin.createNotificationChannel(tasksChannel);
        await androidPlugin.createNotificationChannel(noticesChannel);
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

  // Show immediate Heads-Up Pop-Up Banner on Screen
  Future<void> showHeadsUpNotification({
    required String title,
    required String body,
    String type = 'reminders',
    String? payload,
  }) async {
    final details = _buildChannelDetails(type, title, requireAck: type == 'alerts');
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: details),
      payload: payload ?? 'home',
    );
  }

  // Trigger test notifications for any of the 5 custom sound channels
  Future<void> sendTestNotification(String soundType) async {
    String title = 'CRM Alert Test';
    String body = 'Testing notification popup and custom sound';

    switch (soundType) {
      case 'alarm':
        title = 'Urgent Quick Alert (Alarm Sound)';
        body = 'Insistent siren alert popped up on screen!';
        break;
      case 'reminder':
        title = 'Reminder: Follow-up Scheduled';
        body = 'Two-tone reminder chime popped up on screen!';
        break;
      case 'meeting':
        title = 'Meeting in 15 Minutes';
        body = 'Executive C-Major triad bell popped up on screen!';
        break;
      case 'task':
        title = 'New Task Assigned';
        body = 'Upbeat task pop sound popped up on screen!';
        break;
      case 'notice':
        title = 'New Notice: Team Announcement';
        body = 'Crystal harmonic chime popped up on screen!';
        break;
    }

    await showHeadsUpNotification(
      title: title,
      body: body,
      type: soundType,
      payload: soundType == 'alarm' ? 'quick_alert' : 'home',
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
    final type = data['type'] ?? 'general';
    final bool requireAck = data['require_ack'] == 'true';

    final androidDetails = _buildChannelDetails(type, title, requireAck: requireAck);
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

  // Internal builder for Android Notification Details with heads-up display & 5 custom sounds
  static AndroidNotificationDetails _buildChannelDetails(
    String type,
    String ticker, {
    bool requireAck = false,
  }) {
    String channelId;
    String channelName;
    String soundFile;
    List<AndroidNotificationAction>? actions;
    Int32List? flags;

    switch (type) {
      case 'alerts':
      case 'alarm':
        channelId = 'alerts';
        channelName = 'Urgent Quick Alerts';
        soundFile = 'alarm_alert';
        flags = requireAck ? Int32List.fromList([4]) : null; // FLAG_INSISTENT
        actions = const [
          AndroidNotificationAction('action_seen', 'Seen', showsUserInterface: true),
          AndroidNotificationAction('action_snooze', 'Snooze', showsUserInterface: false),
        ];
        break;
      case 'reminders':
      case 'reminder':
      case 'followup':
        channelId = 'reminders';
        channelName = 'Reminders & Follow-ups';
        soundFile = 'sound_reminder';
        break;
      case 'meetings':
      case 'meeting':
        channelId = 'meetings';
        channelName = 'Meetings & Syncs';
        soundFile = 'sound_meeting';
        break;
      case 'tasks':
      case 'task':
        channelId = 'tasks';
        channelName = 'Task Assignments';
        soundFile = 'sound_task';
        break;
      case 'general':
      case 'notice':
      default:
        channelId = 'general';
        channelName = 'Notice Board & Announcements';
        soundFile = 'sound_notice';
        break;
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ticker: ticker,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundFile),
      enableVibration: true,
      additionalFlags: flags,
      actions: actions,
    );
  }
}
