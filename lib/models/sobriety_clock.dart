class SobrietyClock {
  final int id;
  final String addictionType;
  final String customName;
  final DateTime startDate;

  SobrietyClock({
    required this.id, 
    required this.addictionType, 
    required this.customName, 
    required this.startDate
  });

  factory SobrietyClock.fromJson(Map<String, dynamic> json) {
    return SobrietyClock(
      id: json['id'],
      addictionType: json['addiction_type'],
      customName: json['custom_name'] ?? "",
      startDate: DateTime.parse(json['start_date']),
    );
  }
}
