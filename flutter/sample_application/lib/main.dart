import 'dart:async';

import 'package:dito_sdk/dito_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dito_sample_screen.dart';
import 'env_loader.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await EnvLoader.load();

  final ditoSdk = DitoSdk();
  String? initError;
  try {
    await ditoSdk.setDebugMode(enabled: true);
    await ditoSdk.initialize(
      appKey: EnvLoader.getOrEmpty('API_KEY').trim(),
      appSecret: EnvLoader.getOrEmpty('API_SECRET').trim(),
    );
  } on PlatformException catch (e) {
    initError = e.message;
  }

  runApp(MyApp(ditoSdk: ditoSdk, initError: initError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.ditoSdk, this.initError});

  final DitoSdk ditoSdk;
  final String? initError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<DitoNotificationClick>? _notificationClickSubscription;
  StreamSubscription<RemoteMessage>? _firebaseMessageOpenedSubscription;

  @override
  void initState() {
    super.initState();

    _notificationClickSubscription =
        DitoSdk.onNotificationClick.listen((event) {
      final deeplink = event.deeplink;
      if (deeplink.isEmpty) return;
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text('Deeplink: $deeplink')),
      );
    });

    _firebaseMessageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await widget.ditoSdk.handleNotificationClick(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message == null) return;
      await widget.ditoSdk.handleNotificationClick(message.data);
    });
  }

  @override
  void dispose() {
    _notificationClickSubscription?.cancel();
    _firebaseMessageOpenedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dito SDK Example',
      scaffoldMessengerKey: _scaffoldKey,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: DitoSampleScreen(
        scaffoldKey: _scaffoldKey,
        ditoSdk: widget.ditoSdk,
        initError: widget.initError,
      ),
    );
  }
}
