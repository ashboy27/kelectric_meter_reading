import 'package:flutter/foundation.dart';
import '../models/meter.dart';
import '../models/home_summary.dart';
import '../models/entry.dart';
import '../services/api_service.dart';

class MeterProvider extends ChangeNotifier {
  final _api = ApiService();

  List<Meter> meters = [];
  double homeCurrentMonth = 0.0;
  bool loading = false;

  // Caches for per‑month data
  final Map<String, double> _starts = {};
  final Map<String, List<Entry>> _entries = {};
  final Map<String, int> _levels = {};

  String _key(String id, int y, int m) => '$id-$y-$m';

  int _computeLevel(double usage) {
    if (usage > 200) return 4;
    if (usage > 190) return 3;
    if (usage > 180) return 2;
    if (usage > 170) return 1;
    return 0;
  }

  Future<void> loadSummary() async {
    loading = true;
    notifyListeners();
    try {
      final summary = await _api.fetchHomeSummary();
      meters = summary.meters;
      homeCurrentMonth = summary.homeCurrentMonth;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
  bool hasStart(String meterId, int year, int month) {
    if (_starts['$meterId-$year-$month'] == null) {
      return false;
    }
    return _starts['$meterId-$year-$month']! >0.01;
  }


  Future<void> loadMonthly(String meterId, int year, int month) async {
    try {
      final data = await _api.fetchMonthlyData(meterId, year, month);
      final key = _key(meterId, year, month);

      // 1) Start reading
      _starts[key] = (data['start_reading'] as num).toDouble();

      // 2) Defensive casting of entries
      final rawList = data['entries'];
      if (rawList is! List) {
        debugPrint("⚠️ loadMonthly: expected List in 'entries', got ${rawList.runtimeType}");
        _entries[key] = [];
      } else {
        // If ApiService already returns List<Entry>, this will work, otherwise try-map
        _entries[key] = rawList.every((e) => e is Entry)
            ? List<Entry>.from(rawList as List<Entry>)
            : rawList
            .map((e) {
          try {
            return e as Entry;
          } catch (_) {
            // if it's a Map, try to parse
            return Entry.fromJson(e as Map<String, dynamic>);
          }
        })
            .toList();
      }

      // DEBUG: log how many entries loaded
      debugPrint("✅ loadMonthly: loaded ${_entries[key]!.length} entries for $meterId $year-$month");

      // 3) Compute danger level
      final startVal = _starts[key]!;
      final list    = _entries[key]!;
      final usage   = list.isNotEmpty ? list.first.reading - startVal : 0.0;
      _levels[key]   = _computeLevel(usage);

      notifyListeners();
    } catch (err) {
      debugPrint("❌ loadMonthly error: $err");
      // You may want to rethrow or handle differently
    }
  }


  double? getStart(String meterId, int year, int month) =>
      _starts[_key(meterId, year, month)];

  List<Entry>? getEntries(String meterId, int year, int month) =>
      _entries[_key(meterId, year, month)];

  int getLevel(String meterId, int year, int month) =>
      _levels[_key(meterId, year, month)] ?? 0;

  Future<void> setStart(
      String meterId, int year, int month, double reading) async {
    try {
      await _api.postStartReading(meterId, year, month, reading);
      final key = _key(meterId, year, month);
      _starts[key] = reading;
      _entries[key] = [];
      _levels[key] = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> addEntry(
      String meterId, int year, int month, String name, double value,String postingDate) async {

    final key = _key(meterId, year, month);
    final start = _starts[key];
    if (start == null) {
      throw StateError('Please set the start reading first.');
    }

    final now = DateTime.now();
    final dayStr   = now.day.toString().padLeft(2, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final yearStr  = year.toString();
    final isoDate  = '$yearStr-$monthStr-$dayStr';

    try {
      final level = await _api.postEntry(meterId, isoDate, name, value,postingDate);

      // reload from server rather than optimistic insert
      await loadMonthly(meterId, year, month);
      await loadSummary();
      return level;
    } catch (e) {
      throw Exception('Failed to add reading entry: $e');
    }
  }

  Future<void> removeEntry(
      String meterId, int year, int month, String entryId) async {
    await _api.deleteEntry(meterId, entryId);
    await loadMonthly(meterId, year, month);
    notifyListeners();
  }

  List<String> getMonthNames() =>
      List.generate(12, (i) => DateTime(0, i + 1).month.toString());
}
