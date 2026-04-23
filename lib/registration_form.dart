import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'main.dart';
import 'event_data.dart';
import 'notification_service.dart';

class RegistrationFormScreen extends StatefulWidget {
  final Map<String, String> event;

  const RegistrationFormScreen({super.key, required this.event});

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  late final TextEditingController fullnameController;
  late final TextEditingController phoneController;

  bool isLoading = false;

  bool get _isFull {
    final maxP = int.tryParse(widget.event['max_participants'] ?? '0') ?? 0;
    final currentP = int.tryParse(widget.event['current_participants'] ?? '0') ?? 0;
    return maxP > 0 && currentP >= maxP;
  }

  @override
  void initState() {
    super.initState();
    fullnameController = TextEditingController();
    phoneController = TextEditingController();
  }

  @override
  void dispose() {
    fullnameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void registerForEvent() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    // Live seat check
    try {
      final eventRow = await supabase
          .from('events')
          .select('current_participants, max_participants')
          .eq('id', int.parse(widget.event['id']!))
          .single();
      final maxP = (eventRow['max_participants'] as int?) ?? 0;
      final currentP = (eventRow['current_participants'] as int?) ?? 0;
      if (maxP > 0 && currentP >= maxP) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This event is full. Registration is closed.")),
          );
          setState(() { isLoading = false; });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not verify seat availability. Please try again.")),
        );
        setState(() { isLoading = false; });
      }
      return;
    }

    bool askFullname = widget.event['ask_fullname'] == 'true';
    bool askPhone = widget.event['ask_phone'] == 'true';

    if (askFullname && fullnameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      setState(() { isLoading = false; });
      return;
    }

    if (askPhone && phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your phone number")),
      );
      setState(() { isLoading = false; });
      return;
    }

    try {
      final eventId = int.parse(widget.event['id']!);
      
      // Check if already registered
      final existingRegistration = await supabase
          .from('registrations')
          .select()
          .eq('user_id', user.id)
          .eq('event_id', eventId);

      if (existingRegistration.isNotEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You are already registered for this event"),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Proceed with registration
      final displayName = askFullname 
          ? fullnameController.text.trim() 
          : (user.email ?? 'Participant');
      
      await supabase.from('registrations').insert({
        'user_id': user.id,
        'event_id': eventId,
        'user_fullname': displayName,
        'user_phone': askPhone ? phoneController.text.trim() : null,
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
        // Log but don't fail — count will self-correct on next fetch
        developer.log('Failed to increment participant count: $e');
      }

      // Add to EventData
      EventData.joinedEvents.add(eventId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully registered for event!")),
        );
        // Show reminder bottom sheet; pop the registration form when it closes
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (ctx) => _buildReminderSheetContent(ctx),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error registering: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildReminderSheetContent(BuildContext ctx) {
    if (kIsWeb) {
      // Web guard — bottom sheet won't be shown on web, but just in case
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Reminders are not supported on web',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }

    final eventTitle = widget.event['title'] ?? 'Event';
    final eventDate = widget.event['date'] ?? '';
    final eventTime = widget.event['time'] ?? '';
    final eventId = int.tryParse(widget.event['id'] ?? '0') ?? 0;

    return Padding(
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
                    // Custom: pick date then time
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
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  } else {
                    final eventDateTime =
                        NotificationService.parseEventDateTime(
                            eventDate, eventTime);
                    if (eventDateTime == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not parse event date/time'),
                          ),
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
                        const SnackBar(
                          content: Text('Reminder time has already passed'),
                        ),
                      );
                      break;
                    case ReminderResult.permissionDenied:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notifications are disabled. Please enable them in Settings.',
                          ),
                        ),
                      );
                      break;
                    case ReminderResult.unsupportedPlatform:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Reminders are not supported on this platform'),
                        ),
                      );
                      break;
                  }
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool askFullname = widget.event['ask_fullname'] == 'true';
    bool askPhone = widget.event['ask_phone'] == 'true';

    return Scaffold(
      appBar: AppBar(title: const Text("Event Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event details preview
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient header strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Text(
                        widget.event['title'] ?? 'Event',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "📍 ${widget.event['location'] ?? 'TBD'}",
                            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "📅 ${widget.event['date'] ?? 'TBD'} at ${widget.event['time'] ?? 'TBD'}",
                            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (askFullname || askPhone) ...[
              const Text(
                "Registration Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              if (askFullname) ...[
                TextField(
                  controller: fullnameController,
                  decoration: InputDecoration(
                    labelText: "Full Name *",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (askPhone) ...[
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  "The organizer hasn't requested any additional information.",
                  style: TextStyle(fontSize: 14, color: Color(0xFF0EA5E9)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_isFull) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "This event is full. Registration is closed.",
                        style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Register button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (isLoading || _isFull)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                        ),
                  color: (isLoading || _isFull) ? const Color(0xFFF3F4F6) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (isLoading || _isFull)
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
                  onPressed: isLoading || _isFull ? null : registerForEvent,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          "Register for Event",
                          style: TextStyle(
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
