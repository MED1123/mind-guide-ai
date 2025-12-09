import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../Services/database_service.dart';
import '../Services/api_service.dart';
import '../models/mood_entry.dart';
import '../main.dart';
import '../widgets/mood_card.dart';
import '../widgets/mood_analysis_widget.dart';

class CalendarScreen extends StatefulWidget {
  final Function(MoodEntry) onOpenChat;
  final VoidCallback? onGoToProfile;

  const CalendarScreen({
    super.key,
    this.onOpenChat = _defaultOpenChat,
    this.onGoToProfile,
  });

  static void _defaultOpenChat(MoodEntry e) {}

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<MoodEntry>> _groupedEvents = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    loadEvents();
  }

  void loadEvents() async {
    List<MoodEntry> entries = [];
    final currentUserId = ApiService().currentUserId;

    if (currentUserId == null) return;

    try {
      entries = await ApiService().getEntries();
      if (entries.isEmpty) {
        entries = await DatabaseService.instance.readEntriesForUser(
          currentUserId,
        );
      }
    } catch (e) {
      entries = await DatabaseService.instance.readEntriesForUser(
        currentUserId,
      );
    }

    final Map<DateTime, List<MoodEntry>> data = {};
    for (var entry in entries) {
      final dateKey = DateTime.utc(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (data[dateKey] == null) data[dateKey] = [];
      data[dateKey]!.add(entry);
    }
    if (mounted)
      setState(() {
        _groupedEvents = data;
      });
  }

  List<MoodEntry> _getEventsForDay(DateTime day) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return _groupedEvents[dateKey] ?? [];
  }

  Color _getDotColor(String category) {
    if (category.contains("Stres") ||
        category.contains("Smutek") ||
        category.contains("Złość"))
      return AppColors.cardRed;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calendarCardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                " Twój Kalendarz",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              color: calendarCardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TableCalendar(
                  locale: 'pl_PL',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  daysOfWeekHeight: 30,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: textColor,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: const BoxDecoration(
                      color: Color(0x4D0D47A1),
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: AppColors.textGrey),
                    defaultTextStyle: TextStyle(color: textColor),
                  ),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final entries = events as List<MoodEntry>;
                      final color = _getDotColor(entries.first.category);
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // NOWY WIDGET ANALIZY (z obsługą SWIPE)
          const SliverToBoxAdapter(child: MoodAnalysisWidget()),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
              child: Text(
                _selectedDay != null
                    ? "Wpisy z ${DateFormat('d MMMM', 'pl_PL').format(_selectedDay!)}"
                    : "Wybierz dzień",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          selectedEvents.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Center(
                      child: Text(
                        "Brak wpisów",
                        style: TextStyle(
                          color: AppColors.textGrey.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = selectedEvents[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 6,
                      ),
                      child: Bounceable(
                        scaleFactor: 0.95,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onOpenChat(entry);
                        },
                        child: MoodCard(entry: entry),
                      ),
                    );
                  }, childCount: selectedEvents.length),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
