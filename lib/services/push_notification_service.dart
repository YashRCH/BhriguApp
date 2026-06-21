import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  factory PushNotificationService() => instance;

  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _androidChannelId = 'high_importance_channel';
  static const _androidChannelName = 'High Importance Notifications';
  static const _androidChannelDescription =
      'This channel is used for important notifications.';
  static const _permissionTimeout = Duration(seconds: 4);
  static const _localSetupTimeout = Duration(seconds: 4);
  static const _tokenSaveTimeout = Duration(seconds: 5);
  static const _androidChannel = AndroidNotificationChannel(
    _androidChannelId,
    _androidChannelName,
    description: _androidChannelDescription,
    importance: Importance.max,
  );

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initializeFuture;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _initializeFuture ??= _initialize();

    try {
      await _initializeFuture;
    } finally {
      if (!_initialized) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _requestPermission().timeout(
      _permissionTimeout,
      onTimeout: () {
        if (kDebugMode) {
          debugPrint('Notification permission request timed out.');
        }
      },
    );
    await _setupLocalNotifications().timeout(
      _localSetupTimeout,
      onTimeout: () {
        if (kDebugMode) {
          debugPrint('Local notification setup timed out.');
        }
      },
    );

    _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen((token) {
      unawaited(_saveTokenToDatabase(token));
    });

    _saveCurrentTokenInBackground();

    _authSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _saveCurrentTokenInBackground();
      }
    });

    _foregroundMessageSubscription ??=
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    _initialized = true;
  }

  void _saveCurrentTokenInBackground() {
    unawaited(
      _saveCurrentTokenToDatabase().timeout(
        _tokenSaveTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('FCM token save timed out.');
          }
        },
      ),
    );
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false);

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _saveCurrentTokenToDatabase() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToDatabase(token);
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      // Document might not exist yet if user is just signing up
      debugPrint('Failed to save FCM token (might not exist yet): $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
