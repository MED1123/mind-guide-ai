import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../Services/database_service.dart';
import '../models/mood_entry.dart';
import '../main.dart'; // Potrzebne dla AppColors
// DODANO: Import widżetu MoodCard, który został przeniesiony
import '../widgets/mood_card.dart';

// --- 8. EKRAN KALENDARZA ---
class CalendarScreen extends StatefulWidget {
  final Function(MoodEntry) onOpenChat;

  const CalendarScreen({super.key, this.onOpenChat = _defaultOpenChat});

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
    final entries = await DatabaseService.instance.readAllEntries();
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
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  daysOfWeekHeight: 30,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Color(0x4D0D47A1),
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: AppColors.textGrey),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
              child: Text(
                _selectedDay != null
                    ? "Wpisy z ${DateFormat('d MMMM').format(_selectedDay!)}"
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
                      // Tu występował błąd - teraz MoodCard jest poprawnie zaimportowany
                      child: MoodCard(
                        entry: entry,
                        onTap: () => widget.onOpenChat(entry),
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
