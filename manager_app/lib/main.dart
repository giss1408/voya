import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:voya_ui/voya_ui.dart';

void main() {
  runApp(const VoyaFleetApp());
}

class VoyaFleetApp extends StatelessWidget {
  const VoyaFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voya Fleet',
      debugShowCheckedModeBanner: false,
      theme: voyaTheme(),
      home: const RootGate(),
    );
  }
}

/// Shows login until a staff session exists, then the dashboard.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final ApiClient _api = ApiClient();
  StaffUser? _me;

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return LoginScreen(api: _api, onLoggedIn: (me) => setState(() => _me = me));
    }
    return HomeScreen(
      api: _api,
      me: _me!,
      onLoggedOut: () => setState(() => _me = null),
    );
  }
}
