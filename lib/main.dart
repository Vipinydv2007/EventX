import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration_form.dart';
import 'my_events_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'organizer_screen.dart';
import 'search_screen.dart';
import 'notification_service.dart';

late final SupabaseClient supabase;

void main() async {
  developer.log("APP STARTED");
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  try {
    await Supabase.initialize(
      url: 'https://wccnjpdeykztlupwamxn.supabase.co',
      anonKey: 'sb_publishable_jKVLjN1MNfC8y0TM_BdqZg_mR_t5uFv',
    );

    supabase = Supabase.instance.client;
    developer.log("Supabase Initialized ✅");
  } catch (e) {
    developer.log("Supabase Error: $e");
  }

  runApp(const MyApp());
}

// MAIN APP
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Event Manager',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F9FF),
        primaryColor: const Color(0xFF0EA5E9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF0284C7),
          surface: Colors.white,
          
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF0EA5E9),
          unselectedItemColor: Color(0xFF9CA3AF),
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF3F4F6),
          selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
          labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          secondaryLabelStyle: const TextStyle(color: Color(0xFF0EA5E9), fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Color(0xFF6B7280)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF0F172A),
          contentTextStyle: TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  void checkUser() async {
    await Future.delayed(const Duration(seconds: 1));

    final user = supabase.auth.currentUser;

    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// HOME SCREEN
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int selectedIndex = 0;
  String userRole = 'student';
  String currentMode = 'participant';
  List<Map<String, String>> events = [];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchEvents();
    fetchUserMode();
    initializeUserEventData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App comes to foreground - refresh mode and event data in case they changed
      fetchUserMode();
      initializeUserEventData();
    }
  }

  Future<void> fetchUserMode() async {
    final user = supabase.auth.currentUser;

    try {
      final data = await supabase
          .from('users')
          .select('current_mode')
          .eq('id', user!.id)
          .single();

      setState(() {
        String newMode = data['current_mode'] ?? 'participant';
        currentMode = newMode;
        
        // Validate selectedIndex for the current mode
        // Organizer has 3 tabs (0-2), Participant has 4 tabs (0-3)
        int maxIndex = currentMode == 'organizer' ? 2 : 3;
        if (selectedIndex > maxIndex) {
          selectedIndex = 0;
          developer.log("Reset selectedIndex to 0 (was out of bounds for $currentMode mode)");
        }
      });
    } catch (e) {
      developer.log("Error fetching user mode: $e");
    }
  }

  Future<void> fetchUserRole() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('users')
        .select('role')
        .eq('id', user!.id)
        .single();

    setState(() {
      userRole = data['role'];
    });
  }

  Future<void> _refreshUserData() async {
    // Refresh the user's current mode from database to ensure it's synchronized
    await fetchUserMode();
    developer.log("User data refreshed: currentMode = $currentMode, selectedIndex = $selectedIndex");
  }

  Future<void> fetchEvents() async {
    try {
      final user = supabase.auth.currentUser;

      // 🔴 IMPORTANT CHECK
      if (user == null) {
        developer.log("User not logged in ❌");
        return;
      }

      final data = await supabase.from('events').select();

      setState(() {
        events = List<Map<String, String>>.from(
          data.map(
            (e) => {
              "id": e['id'].toString(),
              "title": e['title'] as String,
              "date": e['date'] as String,
              "time": e['time']?.toString() ?? "",
              "location": e['location']?.toString() ?? "",
              "image": e['image_url']?.toString() ?? "",
              "created_by": e['created_by'].toString(),
              "description": e['description']?.toString() ?? "",
              "max_participants": e['max_participants']?.toString() ?? "0",
              "current_participants": e['current_participants']?.toString() ?? "0",
              "category": e['category']?.toString() ?? "",
              "ask_fullname": e['ask_fullname']?.toString() ?? "false",
              "ask_phone": e['ask_phone']?.toString() ?? "false",
            },
          ),
        );
      });

      developer.log("Data loaded from Supabase ✅");
    } catch (e) {
      developer.log("Fetch Error: $e");
    }
  }

  Future<void> initializeUserEventData() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        developer.log("User not logged in ❌");
        return;
      }

      // Fetch registered events (joined events)
      final registrations = await supabase
          .from('registrations')
          .select('event_id')
          .eq('user_id', user.id);

      // Fetch favorite events
      final favorites = await supabase
          .from('favorites')
          .select('event_id')
          .eq('user_id', user.id);

      // Populate EventData with user's registered and favorite events
      EventData.joinedEvents.clear();
      EventData.favoriteEvents.clear();

      for (var reg in registrations) {
        EventData.joinedEvents.add(reg['event_id'] as int);
      }

      for (var fav in favorites) {
        EventData.favoriteEvents.add(fav['event_id'] as int);
      }

      developer.log(
        "User event data initialized: ${EventData.joinedEvents.length} registered, ${EventData.favoriteEvents.length} favorites ✅",
      );
    } catch (e) {
      developer.log("Error initializing user event data: $e");
    }
  }

  String? _seatDisplay(String maxP, String currentP) {
    final max = int.tryParse(maxP) ?? 0;
    final current = int.tryParse(currentP) ?? 0;
    if (max == 0) return null;
    if (current >= max) return 'Full';
    return '${max - current} seats left';
  }

  Widget _buildOrganizerEventsList() {
    final user = supabase.auth.currentUser;
    final myEvents = events.where((e) => e['created_by'] == user?.id.toString()).toList();

    if (myEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_note,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Events Created Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create your first event to get started",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEventScreen()),
                );
                fetchEvents();
              },
              icon: const Icon(Icons.add),
              label: const Text("Create Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: myEvents.length,
      itemBuilder: (context, index) {
        final event = myEvents[index];

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  event["image"]!.isEmpty
                      ? "https://images.unsplash.com/photo-1505373877841-8d25f7d46678"
                      : event["image"]!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 40, color: Color(0xFF9CA3AF)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event["title"]!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 5),
                        Text(event["date"]!, style: const TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailsScreen(event: event),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0EA5E9),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                          ),
                          child: const Text("View Details", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                          onPressed: () async {
                            // Confirm deletion
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Event"),
                                content: const Text(
                                  "Are you sure you want to delete this event?\nThis action cannot be undone.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await supabase
                                  .from('events')
                                  .delete()
                                  .eq('id', int.parse(event["id"]!));
                              fetchEvents();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    const presets = ['Education', 'Sports', 'Dance', 'Music', 'Technology', 'Arts & Culture', 'Social', 'Other'];
    // Show preset categories that have at least one event, plus 'All'
    final eventCategories = events.map((e) => e['category'] ?? '').where((c) => c.isNotEmpty).toSet();
    final categories = ['All', ...presets.where((c) => eventCategories.contains(c)),
      // Also show any custom categories not in presets
      ...eventCategories.where((c) => !presets.contains(c)).toList()..sort(),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              checkmarkColor: const Color(0xFF0EA5E9),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, String>> get _filteredEvents {
    if (_selectedCategory == 'All') return events;
    return events.where((e) => e['category'] == _selectedCategory).toList();
  }

  // Returns a countdown string for an event date
  String? _countdownLabel(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final eventDate = DateTime(year, month, day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final diff = eventDate.difference(today).inDays;
    if (diff < 0) return null; // past event
    if (diff == 0) return '🔥 Today';
    if (diff == 1) return '⏰ Tomorrow';
    if (diff <= 7) return '📅 $diff days left';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: selectedIndex == 0
          ? AppBar(
              title: const Text("EventHub"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search events',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(events: events),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: selectedIndex == 0
          ? currentMode == 'organizer'
              ? _buildOrganizerEventsList()
              : events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "No Events Yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Tap + to add your first event",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await fetchEvents();
                    await initializeUserEventData();
                  },
                  color: const Color(0xFF0EA5E9),
                  child: Column(
                  children: [
                    _buildCategoryChips(),
                    Expanded(
                      child: ListView.builder(
                  itemCount: _filteredEvents.length + 1,
                  itemBuilder: (context, index) {
                    // First item is the "Welcome" header
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Discover Events 🎉",
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            SizedBox(height: 4),
                            Text("Find and join amazing events near you",
                              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      );
                    }

                    final event = _filteredEvents[index - 1];

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🖼 IMAGE
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                child: Image.network(
                                  event["image"]!.isEmpty
                                      ? "https://images.unsplash.com/photo-1505373877841-8d25f7d46678"
                                      : event["image"]!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: const Color(0xFFF3F4F6),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: const Color(0xFFF3F4F6),
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported, size: 40, color: Color(0xFF9CA3AF)),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              Positioned(
                                top: 10,
                                right: 10,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 20,
                                  child: IconButton(
                                    icon: Icon(
                                      EventData.favoriteEvents.contains(
                                            int.parse(event["id"]!),
                                          )
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: const Color(0xFFF97316),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final id = int.parse(
                                        event["id"]!,
                                      );

                                      if (EventData.favoriteEvents
                                          .contains(id)) {
                                        EventData.favoriteEvents.remove(
                                          id,
                                        );
                                      } else {
                                        EventData.favoriteEvents.add(
                                          id,
                                        );

                                        final user =
                                            supabase.auth.currentUser;

                                        await supabase
                                            .from('favorites')
                                            .insert({
                                              'user_id': user!.id,
                                              'event_id': id,
                                            });
                                      }

                                      setState(() {}); // VERY IMPORTANT
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // 📌 TITLE
                                Text(
                                  event["title"]!,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 📅 DATE
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      event["date"]!,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 5),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      event["time"]!.isEmpty
                                          ? "Time not set"
                                          : event["time"]!,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 5),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        event["location"]!.isEmpty
                                            ? "Location not set"
                                            : event["location"]!,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Category + Seat info row
                                Builder(builder: (context) {
                                  final seatInfo = _seatDisplay(
                                    event["max_participants"] ?? "0",
                                    event["current_participants"] ?? "0",
                                  );
                                  final category = event["category"] ?? "";
                                  if (seatInfo == null && category.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        if (category.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF0EA5E9),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        if (seatInfo != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: seatInfo == 'Full' ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              seatInfo,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: seatInfo == 'Full' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 12),

                                // 🔘 VIEW & DELETE
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EventDetailsScreen(
                                                  event: event,
                                                ),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF0EA5E9),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                                      ),
                                      child: const Text(
                                        "View",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // 🔥 DELETE ONLY IF OWNER AND IN ORGANIZER MODE
                                    if (event["created_by"] ==
                                        supabase
                                            .auth
                                            .currentUser!
                                            .id
                                            .toString() &&
                                        currentMode == 'organizer')
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          await supabase
                                              .from('events')
                                              .delete()
                                              .eq(
                                                'id',
                                                int.parse(
                                                  event["id"]!,
                                                ),
                                              );
                                          fetchEvents();
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                    ),
                  ],
                ),
                )
          : currentMode == 'organizer'
              ? selectedIndex == 1
                  ? OrganizerScreen(events: events)
                  : selectedIndex == 2
                      ? ProfileScreen(
                          key: ValueKey('profile_organizer_$currentMode'),
                          events: events,
                          parentMode: currentMode,
                          onModeChanged: (newMode) {
                            // Update mode and reset tab to 0 to avoid out of bounds error
                            developer.log("Mode changed to: $newMode (from organizer)");
                            setState(() {
                              currentMode = newMode;
                              selectedIndex = 0;  // Reset to first tab
                            });
                            // Refresh user data to ensure consistency
                            _refreshUserData();
                          },
                        )
                      : _buildOrganizerEventsList()
              : selectedIndex == 1
              ? MyEventsScreen(events: events)
              : selectedIndex == 2
                  ? FavoritesScreen(events: events)
                  : ProfileScreen(
                      key: ValueKey('profile_participant_$currentMode'),
                      events: events,
                      parentMode: currentMode,
                      onModeChanged: (newMode) {
                        // Update mode and reset tab to 0 to avoid out of bounds error
                        developer.log("Mode changed to: $newMode (from participant)");
                        setState(() {
                          currentMode = newMode;
                          selectedIndex = 0;  // Reset to first tab for new mode
                        });
                        // Refresh user data to ensure consistency
                        _refreshUserData();
                      },
                    ),

      floatingActionButton: (currentMode == 'organizer' && selectedIndex == 0)
          ? FloatingActionButton(
              backgroundColor: Colors.transparent,
              elevation: 0,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEventScreen()),
                );
                fetchEvents();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            // Validate index against current mode's item count
            int maxIndex = currentMode == 'organizer' ? 2 : 3;
            if (index <= maxIndex) {
              selectedIndex = index;
              // Refresh events when switching tabs to ensure latest data
              if (index == 0 || index == 1) {
                fetchEvents();
              }
            }
          });
        },
        selectedItemColor: currentMode == 'organizer' ? const Color(0xFF0EA5E9) : const Color(0xFF0EA5E9),
        type: BottomNavigationBarType.fixed,
        items: currentMode == 'organizer'
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "My Events"),
                BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Dashboard"),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Events"),
                BottomNavigationBarItem(icon: Icon(Icons.event), label: "My Events"),
                BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
              ],
      ),
    );
  }
}

// ADD / EDIT SCREEN
class AddEventScreen extends StatefulWidget {
  final Map<String, String>? existingEvent;

  const AddEventScreen({super.key, this.existingEvent});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  late final TextEditingController titleController;
  late final TextEditingController dateController;
  late final TextEditingController timeController;
  late final TextEditingController locationController;
  late final TextEditingController maxParticipantsController;
  late final TextEditingController descriptionController;
  late final TextEditingController imageUrlController;
  late final TextEditingController categoryController;

  static const List<String> _presetCategories = [
    'Education',
    'Sports',
    'Dance',
    'Music',
    'Technology',
    'Arts & Culture',
    'Social',
    'Other',
  ];

  String? _selectedCategory;
  bool _isOtherCategory = false;

  bool askFullname = false;
  bool askPhone = false;

  bool get _isEditMode => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    titleController = TextEditingController(text: e?['title'] ?? '');
    descriptionController = TextEditingController(text: e?['description'] ?? '');
    locationController = TextEditingController(text: e?['location'] ?? '');
    dateController = TextEditingController(text: e?['date'] ?? '');
    timeController = TextEditingController(text: e?['time'] ?? '');
    imageUrlController = TextEditingController(text: e?['image'] ?? '');
    maxParticipantsController = TextEditingController(text: e?['max_participants'] == '0' ? '' : (e?['max_participants'] ?? ''));
    categoryController = TextEditingController(text: e?['category'] ?? '');
    askFullname = e?['ask_fullname'] == 'true';
    askPhone = e?['ask_phone'] == 'true';

    // Set category dropdown from existing event
    final existingCategory = e?['category'] ?? '';
    if (existingCategory.isNotEmpty) {
      if (_presetCategories.contains(existingCategory)) {
        _selectedCategory = existingCategory;
        _isOtherCategory = false;
      } else {
        _selectedCategory = 'Other';
        _isOtherCategory = true;
        categoryController = TextEditingController(text: existingCategory);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    timeController.dispose();
    locationController.dispose();
    maxParticipantsController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  void saveEvent() async {
    String title = titleController.text.trim();
    String date = dateController.text.trim();
    String time = timeController.text.trim();
    String location = locationController.text.trim();
    String maxParticipants = maxParticipantsController.text.trim();
    String description = descriptionController.text.trim();
    String imageUrl = imageUrlController.text.trim();
    String category = _isOtherCategory
        ? categoryController.text.trim()
        : (_selectedCategory ?? '');

    if (title.isEmpty || date.isEmpty || time.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        imageUrl = 'https://$imageUrl';
      }
    }

    final eventData = {
      'title': title,
      'date': date,
      'time': time,
      'location': location,
      'max_participants': maxParticipants.isEmpty ? null : int.parse(maxParticipants),
      'description': description,
      'ask_fullname': askFullname,
      'ask_phone': askPhone,
      'category': category.isEmpty ? null : category,
      'image_url': imageUrl.isEmpty ? 'https://images.unsplash.com/photo-1505373877841-8d25f7d46678' : imageUrl,
    };

    try {
      if (_isEditMode) {
        await supabase
            .from('events')
            .update(eventData)
            .eq('id', int.parse(widget.existingEvent!['id']!));
        developer.log("Event updated successfully ✅");
      } else {
        await supabase.from('events').insert({
          ...eventData,
          'created_by': supabase.auth.currentUser!.id,
        });
        developer.log("Event created successfully ✅");
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log("Error saving event: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? "Edit Event" : "Create Event"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📌 BASIC INFO SECTION
            const Text(
              "Basic Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Event Title *",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              hint: const Text("Select a category"),
              items: _presetCategories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                  _isOtherCategory = val == 'Other';
                  if (!_isOtherCategory) {
                    categoryController.clear();
                  }
                });
              },
            ),
            if (_isOtherCategory) ...[
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: "Custom Category",
                  hintText: "e.g. Photography, Cooking...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: "Location *",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: imageUrlController,
              decoration: InputDecoration(
                labelText: "Image URL (optional)",
                hintText: "https://example.com/image.jpg",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 📅 DATE AND TIME SECTION
            const Text(
              "Date & Time",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    dateController.text =
                        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                  });
                }
              },
              child: TextField(
                controller: dateController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Date (DD/MM/YYYY) *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                  hintText: "Tap to select date",
                ),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
                    final hour = picked.hour.toString().padLeft(2, '0');
                    final minute = picked.minute.toString().padLeft(2, '0');
                    timeController.text = "$hour:$minute $period";
                  });
                }
              },
              child: TextField(
                controller: timeController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Time (HH:MM AM/PM) *",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: const Icon(Icons.access_time),
                  hintText: "Tap to select time",
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 👥 PARTICIPANTS SECTION
            const Text(
              "Participant Settings",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: maxParticipantsController,
              decoration: InputDecoration(
                labelText: "Max Participants (optional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // ℹ️ INFO COLLECTION SECTION
            const Text(
              "Request Information from Participants",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              title: const Text("Ask for Full Name"),
              value: askFullname,
              onChanged: (value) {
                setState(() {
                  askFullname = value ?? false;
                });
              },
            ),

            CheckboxListTile(
              title: const Text("Ask for Phone Number (Optional)"),
              value: askPhone,
              onChanged: (value) {
                setState(() {
                  askPhone = value ?? false;
                });
              },
            ),

            const SizedBox(height: 24),

            // ✅ SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: saveEvent,
                  child: Text(
                    _isEditMode ? "Save Changes" : "Create Event",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isLogin = true;

  void authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter email and password")));
      return;
    }

    if (!isLogin && name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter your full name")));
      return;
    }

    try {
      if (isLogin) {
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        developer.log("LOGIN SUCCESS: ${response.user}");
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        // Save user name to users table
        if (response.user != null) {
          try {
            await supabase.from('users').insert({
              'id': response.user!.id,
              'email': email,
              'name': name,
              'current_mode': 'participant',
            });
            developer.log("User profile created with name: $name");
          } catch (dbError) {
            developer.log("Error creating user profile: $dbError");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error saving profile: $dbError")),
              );
            }
          }
        }

        developer.log("SIGNUP SUCCESS: ${response.user}");
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      developer.log("AUTH ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // AUTH SCREEN/login-signup form
  @override
  Widget build(BuildContext context) {
    developer.log("AuthScreen loaded");
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.event_rounded, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "EventHub",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin ? "Welcome back!" : "Join EventHub today",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              // White card — expands to fill remaining space
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // drag handle
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!isLogin) ...[
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: "Full Name",
                              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF0EA5E9)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF0EA5E9)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF0EA5E9)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Gradient button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: authenticate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isLogin ? "Login" : "Sign Up",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() { isLogin = !isLogin; }),
                          child: Text(
                            isLogin
                                ? "Don't have an account? Sign Up"
                                : "Already have an account? Login",
                            style: const TextStyle(
                              color: Color(0xFF0EA5E9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventDetailsScreen extends StatefulWidget {
  final Map<String, String> event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  List<Map<String, dynamic>> participants = [];
  bool isLoadingParticipants = false;
  bool isUserRegistered = false;
  late Map<String, String> _event; // mutable local copy for live seat updates

  @override
  void initState() {
    super.initState();
    _event = Map<String, String>.from(widget.event);
    _checkIfOrganizerAndLoadParticipants();
    _checkRegistrationStatus();
  }

  Future<void> _refreshSeatCount() async {
    try {
      final row = await supabase
          .from('events')
          .select('current_participants')
          .eq('id', int.parse(_event['id']!))
          .single();
      if (mounted) {
        setState(() {
          _event['current_participants'] =
              (row['current_participants'] ?? 0).toString();
        });
      }
    } catch (e) {
      developer.log('Failed to refresh seat count: $e');
    }
  }

  Future<void> _openInMaps(String location) async {
    if (location.isEmpty) return;
    final encoded = Uri.encodeComponent(location);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      developer.log('Could not open maps: $e');
    }
  }

  Future<void> _checkRegistrationStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final eventId = int.parse(_event["id"]!);
      
      // Check database for registration
      final registrations = await supabase
          .from('registrations')
          .select()
          .eq('user_id', user.id)
          .eq('event_id', eventId);

      if (mounted) {
        setState(() {
          isUserRegistered = registrations.isNotEmpty;
        });
      }
    } catch (e) {
      developer.log("Error checking registration status: $e");
    }
  }

  Future<void> _checkIfOrganizerAndLoadParticipants() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Check if current user is the organizer
    if (_event["created_by"] == user.id.toString()) {
      await _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    setState(() {
      isLoadingParticipants = true;
    });

    try {
      final data = await supabase
          .from('registrations')
          .select('user_id, user_fullname, user_phone')
          .eq('event_id', int.parse(_event["id"]!));

      // Fetch user emails for each registration
      List<Map<String, dynamic>> participantsList = [];
      for (var registration in data) {
        final userId = registration['user_id'];
        try {
          final userData = await supabase
              .from('users')
              .select('email')
              .eq('id', userId)
              .single();

          participantsList.add({
            'email': userData['email'] ?? 'Unknown',
            'fullname': registration['user_fullname'],
            'phone': registration['user_phone'],
          });
        } catch (e) {
          participantsList.add({
            'email': 'Unknown',
            'fullname': registration['user_fullname'],
            'phone': registration['user_phone'],
          });
        }
      }

      if (mounted) {
        setState(() {
          participants = participantsList;
          isLoadingParticipants = false;
        });
      }
    } catch (e) {
      developer.log("Error loading participants: $e");
      if (mounted) {
        setState(() {
          isLoadingParticipants = false;
        });
      }
    }
  }

  static String formatShareMessage({
    required String title,
    required String date,
    required String time,
    required String location,
  }) {
    final timePart = time.isNotEmpty ? ' at $time' : '';
    final locationPart = location.isNotEmpty ? ', $location' : '';
    return 'Check out this event: $title on $date$timePart$locationPart';
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isOrganizer = user != null && _event["created_by"] == user.id.toString();
    bool askFullname = _event['ask_fullname'] == 'true';
    bool askPhone = _event['ask_phone'] == 'true';

    final isFavorite = EventData.favoriteEvents.contains(int.parse(_event["id"]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text("EventHub"),
        actions: [
          // 📤 SHARE BUTTON
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share event',
            onPressed: () async {
              try {
                await Share.share(
                  formatShareMessage(
                    title: _event['title'] ?? '',
                    date: _event['date'] ?? '',
                    time: _event['time'] ?? '',
                    location: _event['location'] ?? '',
                  ),
                  subject: _event['title'],
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to share event. Please try again.'),
                    ),
                  );
                }
              }
            },
          ),
          // ❤️ FAVORITE BUTTON
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                final eventId = int.parse(_event["id"]!);
                if (isFavorite) {
                  EventData.favoriteEvents.remove(eventId);
                } else {
                  EventData.favoriteEvents.add(eventId);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFavorite ? "Removed from favorites" : "Added to favorites",
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              child: Image.network(
                _event["image"]!.isEmpty
                    ? "https://images.unsplash.com/photo-1505373877841-8d25f7d46678"
                    : _event["image"]!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 220,
                    width: double.infinity,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    width: double.infinity,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 40, color: Color(0xFF9CA3AF)),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📌 TITLE
                  Text(
                    _event["title"]!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 📅 DATE & TIME
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(_event["date"]!),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _event["time"]!.isEmpty
                            ? "Time not set"
                            : _event["time"]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 📍 LOCATION (tappable → opens Google Maps)
                  GestureDetector(
                    onTap: () => _openInMaps(_event["location"] ?? ''),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _event["location"]!.isEmpty
                                ? "Location not set"
                                : _event["location"]!,
                            style: const TextStyle(
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ),
                        if ((_event["location"] ?? '').isNotEmpty)
                          const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0EA5E9)),
                      ],
                    ),
                  ),

                  // 🏷 CATEGORY
                  if ((_event["category"] ?? "").isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.label_outline, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _event["category"]!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0EA5E9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 💺 SEAT AVAILABILITY
                  Builder(builder: (context) {
                    final maxP = int.tryParse(_event['max_participants'] ?? '0') ?? 0;
                    final currentP = int.tryParse(_event['current_participants'] ?? '0') ?? 0;
                    if (maxP == 0) return const SizedBox.shrink();
                    final isFull = currentP >= maxP;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            isFull ? Icons.event_busy : Icons.event_seat,
                            size: 16,
                            color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFull ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isFull ? 'Event Full' : '${maxP - currentP} seats left',
                              style: TextStyle(
                                fontSize: 12,
                                color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // 📄 DESCRIPTION
                  const Text(
                    "About Event",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _event["description"]!.isEmpty
                        ? "No description provided"
                        : _event["description"]!,
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 20),

                  // � PARTICIPANTS (ORGANIZER ONLY)


                  // 🔘 REGISTER BUTTON (PARTICIPANT ONLY)
                  if (!isOrganizer)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: isUserRegistered
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                ),
                          color: isUserRegistered ? const Color(0xFFF3F4F6) : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isUserRegistered
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isUserRegistered
                              ? null
                              : () {
                                  bool needsInfo = askFullname || askPhone;
                                  if (needsInfo) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RegistrationFormScreen(
                                          event: _event,
                                        ),
                                      ),
                                    ).then((_) {
                                      _checkRegistrationStatus();
                                      _refreshSeatCount();
                                    });
                                  } else {
                                    _quickRegister();
                                  }
                                },
                          child: Text(
                            isUserRegistered ? "Already Registered" : "Register Now",
                            style: TextStyle(
                              color: isUserRegistered ? const Color(0xFF6B7280) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickRegister() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final eventId = int.parse(_event["id"]!);

    try {
      // Check if already registered
      final existingRegistration = await supabase
          .from('registrations')
          .select()
          .eq('user_id', user.id)
          .eq('event_id', eventId);

      if (existingRegistration.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You are already registered for this event"),
            ),
          );
        }
        return;
      }

      // Get user email for display purposes
      final userEmail = user.email ?? 'Participant';

      // Proceed with registration
      await supabase.from('registrations').insert({
        'user_id': user.id,
        'event_id': eventId,
        'user_fullname': userEmail, // Store email as fallback for quick register
      });

      // Increment participant count
      try {
        final row = await supabase
            .from('events')
            .select('current_participants')
            .eq('id', eventId)
            .single();
        final current = (row['current_participants'] as int?) ?? 0;
        await supabase
            .from('events')
            .update({'current_participants': current + 1})
            .eq('id', eventId);
      } catch (e) {
        developer.log('Failed to increment participant count: $e');
      }

      if (mounted) {
        EventData.joinedEvents.add(eventId);
        setState(() {
          isUserRegistered = true;
        });
        await _refreshSeatCount();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registered Successfully ✅"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}

class MyRegistrationsScreen extends StatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  State<MyRegistrationsScreen> createState() => _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends State<MyRegistrationsScreen> {
  List registrations = [];

  @override
  void initState() {
    super.initState();
    fetchRegistrations();
  }

  Future<void> fetchRegistrations() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('registrations')
        .select('event_id, events(title, date)')
        .eq('user_id', user!.id);

    setState(() {
      registrations = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EventHub")),
      body: registrations.isEmpty
          ? const Center(child: Text("No registrations yet"))
          : ListView.builder(
              itemCount: registrations.length,
              itemBuilder: (context, index) {
                final item = registrations[index];
                final event = item['events'];

                return ListTile(
                  title: Text(event['title']),
                  subtitle: Text(event['date']),
                );
              },
            ),
    );
  }
}
