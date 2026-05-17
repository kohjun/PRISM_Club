import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/data/notification_repository.dart';
import '../../notifications/ui/notification_screen.dart';
import '../../saves/ui/saved_items_screen.dart';
import '../../search/ui/search_screen.dart';
import '../../space/ui/space_list_screen.dart';
import 'home_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;

  static const _bodies = [
    HomeScreen(),
    SearchScreen(),
    SpaceListScreen(),
    SavedItemsScreen(),
    NotificationScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _bodies),
        bottomNavigationBar: Consumer(
          builder: (ctx, ref, _) {
            final unread =
                ref.watch(unreadCountProvider).valueOrNull ?? 0;
            return NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '홈',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.search),
                  label: '검색',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: '커뮤니티',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bookmark_outline),
                  selectedIcon: Icon(Icons.bookmark),
                  label: '저장',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 9 ? '9+' : '$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: const Icon(Icons.notifications),
                  label: '알림',
                ),
              ],
            );
          },
        ),
      );
}
