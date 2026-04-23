import 'package:flutter/material.dart';
import 'main.dart';
import 'event_data.dart';
import 'dart:developer' as developer;

class ProfileScreen extends StatefulWidget {
  final List<Map<String, String>> events;
  final Function(String)? onModeChanged;
  final String? parentMode;

  const ProfileScreen({
    super.key,
    required this.events,
    this.onModeChanged,
    this.parentMode,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "User";
  String userEmail = "user@example.com";
  String currentMode = "participant";
  bool _isEditing = false;
  late TextEditingController _nameEditController;
  String? _nameValidationError;

  @override
  void initState() {
    super.initState();
    _nameEditController = TextEditingController();
    _initializeFromParent();
  }

  @override
  void dispose() {
    _nameEditController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent's mode changed, update our local state
    if (oldWidget.parentMode != widget.parentMode && widget.parentMode != null) {
      developer.log("Parent mode changed from ${oldWidget.parentMode} to ${widget.parentMode}");
      setState(() {
        currentMode = widget.parentMode!;
      });
    }
  }

  void _initializeFromParent() {
    // Always fetch user data (name, email) regardless of parentMode
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Fetch user profile data
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          // Properly handle name - check if name exists and is not empty
          final fetchedName = userData['name'];
          if (fetchedName != null && fetchedName.toString().isNotEmpty) {
            userName = fetchedName.toString();
          } else {
            userName = user.email?.split('@').first ?? "User";
          }
          userEmail = user.email ?? "user@example.com";
          // Use parent mode if available, otherwise get from database
          if (widget.parentMode != null) {
            currentMode = widget.parentMode!;
          } else {
            currentMode = userData['current_mode'] ?? "participant";
          }
        });
      }

      developer.log("User data loaded: $userName, Mode: $currentMode, ParentMode: ${widget.parentMode}");
    } catch (e) {
      developer.log("Error fetching user data: $e");
      // Set fallback values if fetch fails
      if (mounted) {
        final user = supabase.auth.currentUser;
        setState(() {
          userName = user?.email?.split('@').first ?? "User";
          userEmail = user?.email ?? "user@example.com";
          // Use parent mode if available
          if (widget.parentMode != null) {
            currentMode = widget.parentMode!;
          }
        });
      }
    }
  }

  Future<void> toggleMode() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final newMode = currentMode == "participant" ? "organizer" : "participant";

      developer.log("Attempting to switch from $currentMode to $newMode");

      // Update database first
      await supabase
          .from('users')
          .update({'current_mode': newMode})
          .eq('id', user.id);

      developer.log("Database update successful to $newMode");

      // Notify parent FIRST so it can update and recreate widgets
      if (mounted) {
        developer.log("Calling onModeChanged callback with $newMode");
        widget.onModeChanged?.call(newMode);
      }

      // Small delay to ensure parent has updated
      await Future.delayed(const Duration(milliseconds: 100));

      // Then update local state
      if (mounted) {
        setState(() {
          currentMode = newMode;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Switched to $newMode mode ✅")),
        );
      }
    } catch (e) {
      developer.log("Error toggling mode: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error switching mode: $e")),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameEditController.text.trim();
    if (newName.isEmpty) {
      setState(() {
        _nameValidationError = "Name cannot be empty";
      });
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('users')
          .update({'name': newName})
          .eq('id', user.id);

      setState(() {
        userName = newName;
        _isEditing = false;
        _nameValidationError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
      }
    } catch (e) {
      developer.log("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOrganizerMode = currentMode == "organizer";

    return Scaffold(
      appBar: AppBar(title: const Text("EventHub")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 📌 PROFILE TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Profile",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Manage your account and preferences",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 📋 ACCOUNT INFORMATION SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Account Information",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userEmail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isOrganizerMode ? "Organizer" : "Participant",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Edit profile section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 20, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Full Name",
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 20, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Email",
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_isEditing)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _nameEditController.text = userName;
                                  _nameValidationError = null;
                                });
                              },
                              icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0EA5E9)),
                              label: const Text(
                                "Edit Profile",
                                style: TextStyle(color: Color(0xFF0EA5E9)),
                              ),
                            ),
                          )
                        else ...[
                          TextField(
                            controller: _nameEditController,
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              prefixIcon: const Icon(Icons.person, color: Color(0xFF0EA5E9)),
                              errorText: _nameValidationError,
                              errorStyle: const TextStyle(color: Color(0xFFEF4444)),
                            ),
                            onChanged: (_) {
                              if (_nameValidationError != null) {
                                setState(() { _nameValidationError = null; });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            readOnly: true,
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                            controller: TextEditingController(text: userEmail),
                            decoration: const InputDecoration(
                              labelText: "Email (cannot be changed)",
                              prefixIcon: Icon(Icons.email, color: Color(0xFF0EA5E9)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _nameEditController.text = userName;
                                      _nameValidationError = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF9CA3AF)),
                                    foregroundColor: const Color(0xFF6B7280),
                                  ),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0EA5E9),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text("Save"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 📊 YOUR ACTIVITY SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Activity",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Overview of your event participation",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Activity cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.event_rounded, color: Color(0xFF0EA5E9), size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                EventData.joinedEvents.length.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Registered Events",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.favorite_rounded, color: Color(0xFFF97316), size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                EventData.favoriteEvents.length.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Favorite Events",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 🔄 MODE TOGGLE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: toggleMode,
                  icon: Icon(isOrganizerMode ? Icons.person : Icons.admin_panel_settings),
                  label: Text(
                    isOrganizerMode ? "Switch to Participant" : "Switch to Organizer",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),



            const SizedBox(height: 20),

            // LOGOUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                title: const Text("Logout", style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
