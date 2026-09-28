import 'package:flutter/material.dart';

import '../ai_chat/ai_chat_screen.dart';
import '../health/health_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// The app's persistent bottom-nav shell (Home / Health / AI Talk /
/// Profile), replacing the old push-only navigation from a bare Home
/// screen. Tabs are kept alive via `IndexedStack` rather than re-pushed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Home', 'Health', 'AI Talk', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onTalkToAi: () => setState(() => _index = 2)),
          const HealthScreen(embedded: true),
          const AiChatScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            key: Key('navHome'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            key: Key('navHealth'),
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          NavigationDestination(
            key: Key('navAiTalk'),
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI Talk',
          ),
          NavigationDestination(
            key: Key('navProfile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
