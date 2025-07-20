// lib/models/meter.dart

/// Represents a utility meter with total and current-month readings.
class Meter {
  final String id;
  final String name;
  final double totalUnits;         // Overall total units
  final double currentMonthUnits;  // Units used in the current month

  Meter({
    required this.id,
    required this.name,
    required this.totalUnits,
    required this.currentMonthUnits,
  });

  /// Creates a Meter from JSON (API response).
  factory Meter.fromJson(Map<String, dynamic> j) {
    return Meter(
      id: j['id'] as String,
      name: j['name'] as String,
      totalUnits: (j['total_units'] as num).toDouble(),
      currentMonthUnits: (j['current_month_units'] as num).toDouble(),
    );
  }

  /// Converts a Meter to JSON (for potential local serialization).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'total_units': totalUnits,
      'current_month_units': currentMonthUnits,
    };
  }
}
