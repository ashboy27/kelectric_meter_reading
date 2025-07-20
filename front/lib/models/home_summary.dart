// lib/models/home_summary.dart

import 'package:flutter/foundation.dart';
import 'meter.dart';

/// Represents the combined summary for a household,
/// including individual meters and aggregated totals.
class HomeSummary {
  /// List of all meters in the household with their stats.
  final List<Meter> meters;

  /// Sum of total units (ever) across all meters.
  final double homeTotal;

  /// Sum of current month usage across all meters.
  final double homeCurrentMonth;

  const HomeSummary({
    required this.meters,
    required this.homeTotal,
    required this.homeCurrentMonth,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final metersJson = json['meters'] as List<dynamic>;
    return HomeSummary(
      meters: metersJson
          .cast<Map<String, dynamic>>()
          .map(Meter.fromJson)
          .toList(),
      homeTotal: (json['home_total'] as num).toDouble(),
      homeCurrentMonth: (json['home_current_month'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'meters': meters.map((m) => m.toJson()).toList(),
    'home_total': homeTotal,
    'home_current_month': homeCurrentMonth,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HomeSummary &&
              runtimeType == other.runtimeType &&
              listEquals(meters, other.meters) &&
              homeTotal == other.homeTotal &&
              homeCurrentMonth == other.homeCurrentMonth;

  @override
  int get hashCode =>
      Object.hash(listHash(meters), homeTotal, homeCurrentMonth);

  // helper for hashing a list
  static int listHash(List list) =>
      list.fold(0, (prev, e) => prev ^ e.hashCode);
}
