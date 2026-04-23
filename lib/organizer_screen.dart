import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'main.dart';
import 'dart:developer' as developer;
import 'dart:async';

int computeTotalEvents(List<Map<dynamic, dynamic>> events) => events.length;

int computeTotalRegistrations(Map<String, int> participantCounts) =>
    participantCounts.values.fold(0, (sum, v) => sum + v);

double? computeAvgFillRate(List<Map<dynamic, dynamic>> events) {
  final qualifying = events.where((e) {
    final max = (e['max_participants'] as int?) ?? 0;
    return max > 0;
  }).toList();
  if (qualifying.isEmpty) return null;
  final rates = qualifying.map((e) {
    final max = (e['max_participants'] as int?) ?? 1;
    final current = (e['current_participants'] as int?) ?? 0;
    return current / max * 100.0;
  });
  return rates.reduce((a, b) => a + b) / rates.length;
}

String truncateTitle(String title, {int maxLength = 10}) =>
    title.length <= maxLength ? title : '${title.substring(0, maxLength)}…';

List<BarChartGroupData> buildChartData(
    List<Map<dynamic, dynamic>> events, Map<String, int> participantCounts) {
  return List.generate(events.length, (i) {
    final eventId = events[i]['id'].toString();
    final count = participantCounts[eventId] ?? 0;
    return BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: count.toDouble(),
          color: const Color(0xFF0EA5E9),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  });
}

class OrganizerScreen extends StatefulWidget {
  final List<Map<String, String>> events;

  const OrganizerScreen({super.key, required this.events});

  @override
  State<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends State<OrganizerScreen> with WidgetsBindingObserver {
  List<Map<dynamic, dynamic>> organizedEvents = [];
  Map<String, int> participantCounts = {};
  Map<String, List<String>> participantNames = {};
  bool _analyticsError = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchOrganizerEventsWithParticipants();
    
    // Set up periodic refresh every 5 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) {
          fetchOrganizerEventsWithParticipants();
        }
      },
    );
  }

  @override
  void didUpdateWidget(OrganizerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when widget is rebuilt with new events
    fetchOrganizerEventsWithParticipants();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchOrganizerEventsWithParticipants();
    }
  }

  Future<void> fetchOrganizerEventsWithParticipants() async {
    try {
      setState(() { _analyticsError = false; });
      final user = supabase.auth.currentUser;
      if (user == null) {
        developer.log("User not logged in");
        return;
      }

      developer.log("Fetching events for user: ${user.id}");

      // Fetch only events created by the logged-in user
      final data = await supabase
          .from('events')
          .select()
          .eq('created_by', user.id);

      developer.log("Found ${data.length} events");

      // Fetch participants for each event
      Map<String, int> newParticipantCounts = {};
      Map<String, List<String>> newParticipantNames = {};

      for (var event in data) {
        final eventId = event['id'].toString();

        try {
          // Fetch registrations for this event with fullname
          final registrations = await supabase
              .from('registrations')
              .select('user_id, user_fullname, user_phone')
              .eq('event_id', int.parse(eventId));

          developer.log("Event $eventId: Found ${registrations.length} registrations");

          newParticipantCounts[eventId] = registrations.length;
          
          // Build participant names from registration data
          List<String> names = [];
          for (var reg in registrations) {
            try {
              // Priority: Use user_fullname if provided
              String displayName = '';
              
              // First, check if user_fullname is provided
              if (reg['user_fullname'] != null && reg['user_fullname'].toString().isNotEmpty) {
                displayName = reg['user_fullname'];
              } else {
                // If no fullname, use a generic label
                displayName = 'Registered Participant';
              }
              
              names.add(displayName);
              developer.log("Participant name: $displayName");
            } catch (e) {
              developer.log("Error processing registration: $e");
              names.add('Registered Participant');
            }
          }
          
          newParticipantNames[eventId] = names;

          developer.log("Event $eventId participants: $names");
        } catch (e) {
          developer.log("Error fetching participants for event $eventId: $e");
          newParticipantCounts[eventId] = 0;
          newParticipantNames[eventId] = [];
        }
      }

      if (mounted) {
        setState(() {
          organizedEvents = data;
          participantCounts = newParticipantCounts;
          participantNames = newParticipantNames;
        });
      }

      developer.log("Organizer events loaded with participants: ${organizedEvents.length}");
    } catch (e) {
      developer.log("Error fetching organizer events: $e");
      setState(() { _analyticsError = true; });
    }
  }

  Widget _buildAnalyticsSection() {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Organizer Dashboard"),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              developer.log("Manual refresh triggered");
              fetchOrganizerEventsWithParticipants();
            },
          ),
        ],
      ),
      body: organizedEvents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  const Icon(
                    Icons.event_busy,
                    size: 80,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "No Organized Events",
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Create an event from Home",
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildAnalyticsSection(),
                Expanded(
                  child: ListView.builder(
                    itemCount: organizedEvents.length,
                    itemBuilder: (context, index) {
                final event = organizedEvents[index];
                final eventId = event['id'].toString();
                final participantCount = participantCounts[eventId] ?? 0;
                final participants = participantNames[eventId] ?? [];

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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title and participant badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                event["title"] ?? event['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "$participantCount Participants",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Event details
                        Text(
                          "Date: ${event['date'] ?? 'N/A'}",
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                        if (event['time'] != null && event['time'].toString().isNotEmpty)
                          Text(
                            "Time: ${event['time']}",
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        if (event['location'] != null && event['location'].toString().isNotEmpty)
                          Text(
                            "Location: ${event['location']}",
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),

                        const SizedBox(height: 12),

                        // Participants list
                        if (participantCount > 0) ...[
                          const Text(
                            "Participants:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: participants
                                  .map(
                                    (participant) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Color(0xFF0EA5E9),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              participant,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ] else
                          const Text(
                            "No participants yet",
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final eventMap = <String, String>{
                                  'id':                   event['id']?.toString() ?? '',
                                  'title':                event['title']?.toString() ?? '',
                                  'description':          event['description']?.toString() ?? '',
                                  'location':             event['location']?.toString() ?? '',
                                  'date':                 event['date']?.toString() ?? '',
                                  'time':                 event['time']?.toString() ?? '',
                                  'image':                event['image_url']?.toString() ?? '',
                                  'max_participants':     event['max_participants']?.toString() ?? '0',
                                  'current_participants': event['current_participants']?.toString() ?? '0',
                                  'category':             event['category']?.toString() ?? '',
                                  'ask_fullname':         event['ask_fullname']?.toString() ?? 'false',
                                  'ask_phone':            event['ask_phone']?.toString() ?? 'false',
                                  'created_by':           event['created_by']?.toString() ?? '',
                                };
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEventScreen(existingEvent: eventMap),
                                  ),
                                );
                                fetchOrganizerEventsWithParticipants();
                              },
                              child: const Text("Edit", style: TextStyle(color: Color(0xFF0EA5E9))),
                            ),
                            TextButton(
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
                                          style: TextStyle(color: Color(0xFFEF4444)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  try {
                                    await supabase
                                        .from('events')
                                        .delete()
                                        .eq('id', int.parse(eventId));
                                    
                                    developer.log("Event $eventId deleted from database");
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Event deleted successfully")),
                                      );
                                      fetchOrganizerEventsWithParticipants();
                                    }
                                  } catch (e) {
                                    developer.log("Error deleting event: $e");
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Error deleting event: $e")),
                                      );
                                    }
                                  }
                                }
                              },
                              child: const Text(
                                "Delete",
                                style: TextStyle(color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
                  ),
                ),
              ],
            ),
    );
  }
}