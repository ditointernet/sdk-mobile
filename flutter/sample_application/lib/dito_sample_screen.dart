import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';

import 'sample_app_state.dart';
import 'sections/configuration_section.dart';
import 'sections/event_section.dart';
import 'sections/status_section.dart';
import 'sections/token_section.dart';
import 'sections/user_data_section.dart';

class DitoSampleScreen extends StatefulWidget {
  const DitoSampleScreen({
    super.key,
    required this.scaffoldKey,
    required this.ditoSdk,
    this.initError,
  });

  final GlobalKey<ScaffoldMessengerState> scaffoldKey;
  final DitoSdk ditoSdk;
  final String? initError;

  @override
  State<DitoSampleScreen> createState() => _DitoSampleScreenState();
}

class _DitoSampleScreenState extends State<DitoSampleScreen> {
  late final SampleAppState _state;

  @override
  void initState() {
    super.initState();
    _state = SampleAppState(
      setState: (fn) {
        if (mounted) setState(fn);
      },
      scaffoldKey: widget.scaffoldKey,
      ditoSdk: widget.ditoSdk,
      initError: widget.initError,
    );
    _state.loadEnvValues();
    _state.initPlatformVersion();
    _state.loadFcmToken();
    _state.initFcmDebug();
    _state.setupFcmMessageListeners(() {
      if (mounted) {
        setState(() => _state.fcmPushReceivedCount += 1);
      }
    });
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dito SDK Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusSection(state: _state),
            const SizedBox(height: 16),
            ConfigurationSection(state: _state),
            const SizedBox(height: 16),
            UserDataSection(state: _state),
            const SizedBox(height: 16),
            EventSection(state: _state),
            const SizedBox(height: 16),
            TokenSection(state: _state),
          ],
        ),
      ),
    );
  }
}
