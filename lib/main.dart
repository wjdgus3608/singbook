import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/list_screen.dart';
import 'screens/search_screen.dart';
import 'screens/recognize_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SingbookApp());
}

class SingbookApp extends StatelessWidget {
  const SingbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내 노래책',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _RootScaffold(),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _tab = 0;
  final _listKey = GlobalKey<ListScreenState>();

  late final _screens = [
    ListScreen(key: _listKey),
    const SearchScreen(),
    const RecognizeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _tab,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        color: AppColors.navBg,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music,
                  label: '내 노래책',
                  active: _tab == 0,
                  onTap: () {
                    setState(() => _tab = 0);
                    _listKey.currentState?.reload();
                  },
                ),
                _NavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  label: '검색',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                _NavItem(
                  icon: Icons.mic_none_outlined,
                  activeIcon: Icons.mic,
                  label: '인식',
                  active: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? AppColors.accent : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? AppColors.accentLight : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
