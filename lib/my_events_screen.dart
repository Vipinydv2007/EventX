import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'event_data.dart';
import 'main.dart';
import 'notification_service.dart';

class MyEventsScreen extends StatefulWidget {
  final List<Map<String, String>> events;

  const MyEventsScreen({super.key, required this.events});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List<Map<String, String>> _localJoinedEvents = [];

  @override
  void initState() {
    super.initState();
    _localJoinedEvents = widget.events.where((event) {
      return EventData.joinedEvents.contains(int.parse(event["id"]!));
    }).toList();
  }

  void _showReminderBottomSheet(BuildContext context, Map<String, String> event) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminders are not supported on web')),
      );
      return;
    }

    final eventTitle = event['title'] ?? 'Event';
    final eventDate = event['date'] ?? '';
    final eventTime = event['time'] ?? '';
    final eventId = int.tryParse(event['id'] ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Set Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            ...ReminderInterval.values.map((interval) => ListTile(
              leading: const Icon(Icons.alarm, color: Color(0xFF0EA5E9)),
              title: Text(
                interval.label,
                style: const TextStyle(color: Color(0xFF0F172A)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                DateTime? fireTime;

                if (interval == ReminderInterval.custom) {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate == null || !mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime == null || !mounted) return;
                  fireTime = DateTime(
                    pickedDate.year, pickedDate.month, pickedDate.day,
                    pickedTime.hour, pickedTime.minute,
                  );
                } else {
                  final eventDateTime =
                      NotificationService.parseEventDateTime(eventDate, eventTime);
                  if (eventDateTime == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not parse event date/time')),
                      );
                    }
                    return;
                  }
                  fireTime = eventDateTime.subtract(interval.offset);
                }

                final result = await NotificationService().scheduleReminder(
                  eventId: eventId,
                  eventTitle: eventTitle,
                  fireTime: fireTime,
                );

                if (!mounted) return;
                switch (result) {
                  case ReminderResult.scheduled:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder set! ✅')),
                    );
                    break;
                  case ReminderResult.pastTime:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder time has already passed')),
                    );
                    break;
                  case ReminderResult.permissionDenied:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications are disabled. Please enable them in Settings.'),
                      ),
                    );
                    break;
                  case ReminderResult.unsupportedPlatform:
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminders are not supported on this platform')),
                    );
                    break;
                }
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelRegistration(Map<String, String> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Registration"),
        content: Text(
            "Are you sure you want to cancel your registration for \"${event['title']}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Cancel Registration",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final id = int.parse(event["id"]!);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Delete registration
      await supabase
          .from('registrations')
          .delete()
          .eq('user_id', user.id)
          .eq('event_id', id);

      // Decrement participant count
      try {
        final row = await supabase
            .from('events')
            .select('current_participants')
            .eq('id', id)
            .single();
        final current = (row['current_participants'] as int?) ?? 0;
        if (current > 0) {
          await supabase
              .from('events')
              .update({'current_participants': current - 1}).eq('id', id);
        }
      } catch (e) {
        developer.log('Failed to decrement participant count: $e');
      }

      // Update local state
      EventData.joinedEvents.remove(id);
      // Cancel any scheduled reminder for this event
      await NotificationService().cancelReminder(id);
      setState(() {
        _localJoinedEvents.removeWhere((e) => e['id'] == event['id']);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration cancelled successfully")),
        );
      }
    } catch (e) {
      developer.log('Error cancelling registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling registration: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EventHub"),
      ),
      body: _localJoinedEvents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note,
                    size: 64,
                    color: const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No registered events",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Join events to see them here",
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
              itemCount: _localJoinedEvents.length,
              itemBuilder: (context, index) {
                final event = _localJoinedEvents[index];

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
                              loadingBuilder:
                                  (context, child, loadingProgress) {
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
                                    child: Icon(Icons.image_not_supported,
                                        size: 40, color: Color(0xFF9CA3AF)),
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
                                          int.parse(event["id"]!))
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: const Color(0xFFF97316),
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final id = int.parse(event["id"]!);

                                  if (EventData.favoriteEvents.contains(id)) {
                                    EventData.favoriteEvents.remove(id);
                                  } else {
                                    EventData.favoriteEvents.add(id);

                                    final user = supabase.auth.currentUser;

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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EventDetailsScreen(
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

                            // 🔔 SET REMINDER
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showReminderBottomSheet(context, event),
                                icon: const Icon(Icons.alarm, size: 16, color: Color(0xFF0EA5E9)),
                                label: const Text(
                                  "Set Reminder",
                                  style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF0EA5E9)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),

                            // 🚫 CANCEL REGISTRATION
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _cancelRegistration(event),
                                icon: const Icon(Icons.cancel_outlined,
                                    size: 16, color: Color(0xFFEF4444)),
                                label: const Text(
                                  "Cancel Registration",
                                  style: TextStyle(
                                      color: Color(0xFFEF4444), fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                              ),
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
