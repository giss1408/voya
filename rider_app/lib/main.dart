import 'package:flutter/material.dart';

import 'api_client.dart';
import 'screens/my_tickets_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';

void main() {
  runApp(const VoyaApp());
}

class VoyaApp extends StatelessWidget {
  const VoyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voya',
      debugShowCheckedModeBanner: false,
      theme: voyaTheme(),
      home: const RootShell(),
    );
  }
}

/// Bottom-nav shell holding the two top-level destinations: Search and
/// My tickets. Each tab keeps its own navigation stack.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final ApiClient _api = ApiClient();
  int _tab = 0;

  final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          Navigator(
            key: _navKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => SearchScreen(api: _api),
            ),
          ),
          Navigator(
            key: _navKeys[1],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => MyTicketsScreen(api: _api),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: VoyaColors.surface,
        indicatorColor: VoyaColors.ochre.withOpacity(0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'My tickets'),
        ],
      ),
    );
  }
}
