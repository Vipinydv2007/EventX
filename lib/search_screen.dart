import 'package:flutter/material.dart';
import 'main.dart';
import 'event_data.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, String>> events;

  const SearchScreen({super.key, required this.events});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String searchQuery = '';
  late List<Map<String, String>> filteredEvents;
  String _selectedCategory = 'All';
  String _selectedDateRange = 'All Dates';

  @override
  void initState() {
    super.initState();
    filteredEvents = widget.events;
  }

  void _applyFilters() {
    setState(() {
      filteredEvents = widget.events.where((event) {
        // Text filter
        final q = searchQuery.toLowerCase();
        final matchesText = q.isEmpty ||
            (event["title"] ?? '').toLowerCase().contains(q) ||
            (event["date"] ?? '').toLowerCase().contains(q) ||
            (event["location"] ?? '').toLowerCase().contains(q);

        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            (event["category"] ?? '') == _selectedCategory;

        // Date range filter
        final matchesDate = _matchesDateRange(event["date"] ?? '');

        return matchesText && matchesCategory && matchesDate;
      }).toList();
    });
  }

  bool _matchesDateRange(String dateStr) {
    if (_selectedDateRange == 'All Dates') return true;
    // dateStr format: DD/MM/YYYY
    final parts = dateStr.split('/');
    if (parts.length != 3) return false;
    final eventDate = DateTime.tryParse(
        '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
    if (eventDate == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventOnly =
        DateTime(eventDate.year, eventDate.month, eventDate.day);

    switch (_selectedDateRange) {
      case 'Upcoming':
        return !eventOnly.isBefore(todayOnly);
      case 'This Week':
        return !eventOnly.isBefore(todayOnly) &&
            eventOnly.isBefore(todayOnly.add(const Duration(days: 7)));
      case 'This Month':
        return eventDate.year == today.year &&
            eventDate.month == today.month;
      default:
        return true;
    }
  }

  Widget _buildCategoryChips() {
    const presets = ['Education', 'Sports', 'Dance', 'Music', 'Technology', 'Arts & Culture', 'Social', 'Other'];
    final eventCategories = widget.events.map((e) => e['category'] ?? '').where((c) => c.isNotEmpty).toSet();
    final categories = ['All', ...presets.where((c) => eventCategories.contains(c)),
      ...eventCategories.where((c) => !presets.contains(c)).toList()..sort(),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                _applyFilters();
              },
              selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF0EA5E9),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF6B7280),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRangeChips() {
    const options = ['All Dates', 'Upcoming', 'This Week', 'This Month'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: options.map((opt) {
          final isSelected = _selectedDateRange == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedDateRange = opt;
                });
                _applyFilters();
              },
              selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF6B7280),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Events")),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search events by title, date, location...",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0EA5E9),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color(0xFF0EA5E9),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  searchQuery = value;
                  _applyFilters();
                },
              ),
            ),
          ),
          // 🏷 CATEGORY CHIPS
          _buildCategoryChips(),
          // 📅 DATE RANGE CHIPS
          _buildDateRangeChips(),
          // 🔢 RESULT COUNT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${filteredEvents.length} event(s) found",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // 📋 SEARCH RESULTS
          Expanded(
            child: filteredEvents.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "No events found",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];

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
                                      child: Icon(
                                          Icons.image_not_supported,
                                          size: 40, color: Color(0xFF9CA3AF)),
                                    ),
                                  );
                                },
                              ),
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
                                      fontSize: 18,
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

                                  // 🕐 TIME
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

                                  // 📍 LOCATION
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
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // 🔘 VIEW BUTTON
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
          ),
        ],
      ),
    );
  }
}
