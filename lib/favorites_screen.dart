import 'package:flutter/material.dart';
import 'event_data.dart';
import 'main.dart';

class FavoritesScreen extends StatefulWidget {
  final List<Map<String, String>> events;

  const FavoritesScreen({super.key, required this.events});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    // filter favorite events
    final favoriteEvents = widget.events.where((event) {
      return EventData.favoriteEvents.contains(
        int.parse(event["id"]!),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("EventHub"),
      ),
      body: favoriteEvents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: const Color(0xFFF97316),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No favorite events",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Save events to easily find them later",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.explore),
                    label: const Text("Browse Events"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favoriteEvents.length,
              itemBuilder: (context, index) {
                final event = favoriteEvents[index];

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
                                icon: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFF97316),
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final id = int.parse(
                                    event["id"]!,
                                  );

                                  EventData.favoriteEvents.remove(id);

                                  // Also remove from database
                                  final user = supabase.auth.currentUser;
                                  await supabase
                                      .from('favorites')
                                      .delete()
                                      .eq('user_id', user!.id)
                                      .eq('event_id', id);

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

                            const SizedBox(height: 12),

                            // 🔘 VIEW DETAILS
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
                                    "View Details",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
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
    );
  }
}