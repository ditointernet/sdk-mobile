import 'dart:async';

import 'package:dito_sdk/dito_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'env_loader.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvLoader.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _ditoSdk = DitoSdk();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  String _status = 'Not initialized';
  bool _isInitialized = false;
  String _platformVersion = 'Unknown';
  final bool _debugModeEnabled = true;

  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _userIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _userAddressController = TextEditingController();
  final _userCityController = TextEditingController();
  final _userStateController = TextEditingController();
  final _userZipController = TextEditingController();
  final _userCountryController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _tokenController = TextEditingController();
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadEnvValues();
    _initPlatformState();
    _loadFcmToken();
  }

  void _loadEnvValues() {
    final identifyId = EnvLoader.getOrEmpty('IDENTIFY_ID');
    final identifyName = EnvLoader.getOrEmpty('IDENTIFY_NAME');
    final identifyEmail = EnvLoader.getOrEmpty('IDENTIFY_EMAIL');

    setState(() {
      _apiKeyController.text = EnvLoader.getOrEmpty('API_KEY');
      _apiSecretController.text = EnvLoader.getOrEmpty('API_SECRET');
      _userIdController.text = EnvLoader.getOrEmpty('USER_ID');
      _userNameController.text = EnvLoader.getOrEmpty('USER_NAME');
      _userEmailController.text = EnvLoader.getOrEmpty('USER_EMAIL');
      _userPhoneController.text = EnvLoader.getOrEmpty('USER_PHONE');
      _userAddressController.text = EnvLoader.getOrEmpty('USER_ADDRESS');
      _userCityController.text = EnvLoader.getOrEmpty('USER_CITY');
      _userStateController.text = EnvLoader.getOrEmpty('USER_STATE');
      _userZipController.text = EnvLoader.getOrEmpty('USER_ZIP');
      _userCountryController.text = EnvLoader.getOrEmpty('USER_COUNTRY');

      if (_userIdController.text.isEmpty && identifyId.isNotEmpty) {
        _userIdController.text = identifyId;
      }
      if (_userNameController.text.isEmpty && identifyName.isNotEmpty) {
        _userNameController.text = identifyName;
      }
      if (_userEmailController.text.isEmpty && identifyEmail.isNotEmpty) {
        _userEmailController.text = identifyEmail;
      }
    });
  }

  Future<void> _initPlatformState() async {
    try {
      final version = await _ditoSdk.getPlatformVersion() ?? 'Unknown';
      if (mounted) {
        setState(() {
          _platformVersion = version;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _platformVersion = 'Failed: ${e.message}';
        });
      }
    }
  }

  Future<void> _loadFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _tokenController.text = token;
      }
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) {
            if (newToken.isNotEmpty) {
              _tokenController.text = newToken;
            }
          });
    } on Exception {}
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _initialize() async {
    try {
      _log('initialize start');
      await _ditoSdk.setDebugMode(enabled: _debugModeEnabled);
      await _ditoSdk.initialize(
        appKey: _apiKeyController.text.trim(),
        appSecret: _apiSecretController.text.trim(),
      );
      setState(() {
        _status = 'Initialized successfully';
        _isInitialized = true;
      });
      _log('initialize success');
      _showSnackBar('SDK initialized successfully');
    } on PlatformException catch (e) {
      _log('initialize error: ${e.code} ${e.message}');
      setState(() {
        _status = 'Initialization failed: ${e.message}';
        _isInitialized = false;
      });
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> _identify() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }

    final userId = _userIdController.text.trim();
    final email = _userEmailController.text.trim();

    if (userId.isEmpty) {
      _showSnackBar('User ID is required', isError: true);
      return;
    }

    if (email.isNotEmpty && !_validateEmail(email)) {
      _showSnackBar('Invalid email format', isError: true);
      return;
    }

    try {
      _log('identify start: $userId');
      final customData = <String, dynamic>{};
      if (_userPhoneController.text.trim().isNotEmpty) {
        customData['phone'] = _userPhoneController.text.trim();
      }
      if (_userAddressController.text.trim().isNotEmpty) {
        customData['address'] = _userAddressController.text.trim();
      }
      if (_userCityController.text.trim().isNotEmpty) {
        customData['city'] = _userCityController.text.trim();
      }
      if (_userStateController.text.trim().isNotEmpty) {
        customData['state'] = _userStateController.text.trim();
      }
      if (_userZipController.text.trim().isNotEmpty) {
        customData['zip'] = _userZipController.text.trim();
      }
      if (_userCountryController.text.trim().isNotEmpty) {
        customData['country'] = _userCountryController.text.trim();
      }

      await _ditoSdk.identify(
        id: userId,
        name: _userNameController.text.trim().isEmpty ? null : _userNameController.text.trim(),
        email: email.isEmpty ? null : email,
        customData: customData.isEmpty ? null : customData,
      );
      _log('identify success: $userId');
      _showSnackBar('User identified successfully');
    } on PlatformException catch (e) {
      _log('identify error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> _track() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }

    final eventName = _eventNameController.text.trim();
    if (eventName.isEmpty) {
      _showSnackBar('Event name is required', isError: true);
      return;
    }

    try {
      _log('track start: $eventName');
      await _ditoSdk.track(
        action: eventName,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': _platformVersion,
        },
      );
      _log('track success: $eventName');
      _showSnackBar('Event tracked successfully');
    } on PlatformException catch (e) {
      _log('track error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> _registerToken() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }

    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showSnackBar('Device token is required', isError: true);
      return;
    }

    try {
      _log('register token start');
      await _ditoSdk.registerDeviceToken(token);
      _log('register token success');
      _showSnackBar('Device token registered successfully');
    } on PlatformException catch (e) {
      _log('register token error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> _unregisterToken() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }

    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showSnackBar('Device token is required', isError: true);
      return;
    }

    try {
      _log('unregister token start');
      await _ditoSdk.unregisterDeviceToken(token);
      _log('unregister token success');
      _showSnackBar('Device token unregistered successfully');
    } on PlatformException catch (e) {
      _log('unregister token error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  void _log(String message) {
    debugPrint('[DitoSample] $message');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dito SDK Example',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Dito SDK Example'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusSection(),
              const SizedBox(height: 16),
              _buildConfigurationSection(),
              const SizedBox(height: 16),
              _buildUserDataSection(),
              const SizedBox(height: 16),
              _buildEventSection(),
              const SizedBox(height: 16),
              _buildTokenSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SDK Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Platform: $_platformVersion'),
            const SizedBox(height: 4),
            Text('Status: $_status'),
            const SizedBox(height: 4),
            Text('Initialized: $_isInitialized'),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiSecretController,
              decoration: const InputDecoration(
                labelText: 'API Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Initialize'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userNameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userEmailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userAddressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userCityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _userStateController,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userZipController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _userCountryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _identify,
              child: const Text('Identify User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Event',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _track,
              child: const Text('Track Event'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Token',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'FCM Device Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _registerToken,
                    child: const Text('Register Token'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _unregisterToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Unregister Token'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _userIdController.dispose();
    _userNameController.dispose();
    _userEmailController.dispose();
    _userPhoneController.dispose();
    _userAddressController.dispose();
    _userCityController.dispose();
    _userStateController.dispose();
    _userZipController.dispose();
    _userCountryController.dispose();
    _eventNameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
