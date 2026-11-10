import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Technical Implementation: Phase 2
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase integration
import 'package:trade_match/theme.dart';
import 'package:trade_match/auth/auth_page.dart';
import 'package:trade_match/auth/welcome_page.dart';
import 'package:trade_match/auth/forgot_password.dart';
import 'package:trade_match/chat/chat_list.dart';
import 'package:trade_match/profile/profile.dart';
import 'package:trade_match/profile/settings_page.dart';
import 'package:trade_match/screens/add_item_page.dart';
import 'package:trade_match/screens/explore_screen.dart';
import 'package:trade_match/screens/item_detail_page.dart';
import 'package:trade_match/screens/library_screen.dart';
import 'package:trade_match/screens/notifications_page.dart';
import 'package:trade_match/screens/reviews_page.dart';
import 'package:trade_match/screens/search_filter_page.dart';
import 'package:trade_match/screens/trade_history_page.dart';
// TradeOfferPage removed - swipe/like creates matches directly
import 'package:trade_match/models/barter_item.dart';

import 'package:trade_match/services/constants.dart';
import 'package:trade_match/services/storage_service.dart'; // Phase 2
import 'package:trade_match/services/cache_manager.dart'; // Phase 2
import 'package:trade_match/services/supabase_service.dart'; // For notification badges
import 'package:trade_match/services/notification_service.dart';

void main() async {
  print('🚀 [MAIN] Starting app initialization...');
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  print('✅ [MAIN] WidgetsFlutterBinding initialized');

  // SUPABASE INITIALIZATION
  print('⏳ [MAIN] Initializing Supabase...');
  print('   URL: $SUPABASE_URL');
  print('   Key length: ${SUPABASE_ANON_KEY.length} chars');
  try {
    await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
    print('✅ [MAIN] Supabase initialized successfully');
    print(
      '   Client state: ${Supabase.instance.client.auth.currentSession != null ? "Session exists" : "No session"}',
    );
  } catch (e, stackTrace) {
    print('❌ [MAIN] Supabase initialization FAILED!');
    print('   Error: $e');
    print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
  }

  // PHASE 2: Initialize Hive + StorageService + CacheManager with fallback
  print('⏳ [MAIN] Initializing Hive storage...');
  try {
    await Hive.initFlutter();
    print('✅ [MAIN] Hive initialized successfully');

    // Initialize StorageService (register adapters, open boxes)
    await StorageService.init();
    print('✅ [MAIN] StorageService initialized');

    // Cleanup expired cache entries on startup
    await CacheManager.cleanupExpiredData();
    print('✅ [MAIN] Cache cleanup complete');

    // Initialize NotificationService
    await NotificationService().init();
    print('✅ [MAIN] NotificationService initialized');
  } catch (e, stackTrace) {
    print('❌ [MAIN] Storage initialization FAILED!');
    print('   Error: $e');
    print('   Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
  }

  print('🎬 [MAIN] Launching MyApp widget...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeMatch',
      theme: AppTheme.lightTheme(),
      // Routes. Some routes read ModalRoute.arguments to receive objects.
      routes: {
        '/settings': (context) => const SettingsPage(),
        '/add_item': (context) => const AddItemPage(),
        // MatchesPage removed - Chat tab shows active matches
        '/notifications': (context) => const NotificationsPage(),
        '/search': (context) => const SearchFilterPage(),
        '/trade_history': (context) => const TradeHistoryPage(),
        '/auth': (context) => const AuthPage(),
        '/main': (context) => const MainPage(),
      },
      // Named routes that need arguments are provided here using closures.
      onGenerateRoute: (settings) {
        if (settings.name == '/item_detail') {
          final item = settings.arguments as BarterItem?;
          if (item != null) {
            return MaterialPageRoute(
              builder: (_) => ItemDetailPage(item: item),
            );
          }
        }
        // TradeOfferPage route removed - non-functional feature
        if (settings.name == '/reviews') {
          final userId = settings.arguments as String?;
          if (userId != null) {
            return MaterialPageRoute(
              builder: (_) => ReviewsPage(userId: userId),
            );
          }
        }
        // If the route is not found or arguments are invalid, show an error page.
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Error: Route not found or arguments are invalid.'),
            ),
          ),
        );
      },
      debugShowCheckedModeBanner: false,
      // Start with the SplashPage to check for persistent login
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    print('🔍 [SPLASH] SplashPage initState called');
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    print('🔐 [SPLASH] Starting auth check...');
    try {
      print('   [SPLASH] Accessing Supabase client...');
      final client = Supabase.instance.client;
      print('   [SPLASH] Client obtained, checking session...');

      final session = client.auth.currentSession;
      print(
        '   [SPLASH] Session check complete: ${session != null ? "Session found" : "No session"}',
      );

      // Use addPostFrameCallback to navigate AFTER the current frame completes
      // This prevents Navigator._debugLocked errors
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          print(
            '⚠️ [SPLASH] Widget not mounted after frame, skipping navigation',
          );
          return;
        }

        if (session != null) {
          print('✅ [SPLASH] User authenticated, userId: ${session.user.id}');
          AUTH_USER_ID = session.user.id;
          print('🚀 [SPLASH] Navigating to /main...');
          Navigator.pushReplacementNamed(context, '/main');
          print('✅ [SPLASH] Navigation to /main initiated');
        } else {
          print('🔓 [SPLASH] No active session found');
          print('🚀 [SPLASH] Navigating to WelcomePage...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WelcomePage()),
          );
          print('✅ [SPLASH] Navigation to WelcomePage initiated');
        }
      });
    } catch (e, stackTrace) {
      print('❌ [SPLASH] Auth check FAILED!');
      print('   Error: $e');
      print('   Type: ${e.runtimeType}');
      print(
        '   Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );

      // Use addPostFrameCallback for error recovery too
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          print('⚠️ [SPLASH] Widget not mounted, cannot navigate');
          return;
        }
        print('🚀 [SPLASH] Navigating to WelcomePage (error recovery)...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
        print(
          '✅ [SPLASH] Navigation to WelcomePage initiated (error recovery)',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed logging here to prevent rebuild loops
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();

  final List<Widget> _pages = [
    const ExploreScreen(),
    const ChatListScreen(),
    const LibraryScreen(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToGlobalMessages();
  }

  void _subscribeToGlobalMessages() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;
            // Don't notify if I sent it
            if (newMessage['sender_user_id'] == userId) return;

            // In a real app, you'd check if the user is currently chatting in this room
            // For now, simple notification for all incoming messages
            final content = newMessage['message_text'] ?? 'New message';

            NotificationService().showNotification(
              id:
                  (newMessage['id'] as int? ??
                      DateTime.now().millisecondsSinceEpoch) %
                  100000,
              title: 'New Message',
              body: content,
              payload: newMessage['swap_id'].toString(),
            );
          },
        )
        .subscribe();
  }

  void _onItemTapped(int index) {
    // Add a check to prevent navigation to a non-existent page
    if (index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add_item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2.0,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 3.0,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.swap_horiz, 'Explore', 0),
            // Chat with notification badge
            StreamBuilder<int>(
              stream: _supabaseService.getUnreadMessagesCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return _buildNavItem(
                  Icons.chat_bubble_outline,
                  'Chat',
                  1,
                  badgeCount: unreadCount,
                );
              },
            ),
            const SizedBox(width: 40), // The space for the FAB
            _buildNavItem(Icons.inventory_2_outlined, 'Library', 2),
            _buildNavItem(Icons.person_outline, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
