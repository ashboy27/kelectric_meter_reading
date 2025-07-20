import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/meter.dart';
import '../models/entry.dart';
import '../providers/meter_provider.dart';

class MeterDetailScreen extends StatefulWidget {
  final Meter meter;
  const MeterDetailScreen({super.key, required this.meter});

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen>
    with SingleTickerProviderStateMixin {
  late int selectedYear;
  late int selectedMonth;
  final _readingController = TextEditingController();

  // For posting date fields
  final _postingDayController = TextEditingController();
  final _postingMonthController = TextEditingController();
  final _postingYearController = TextEditingController();

  // Theme Colors
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color alertColor   = Color(0xFFEF4444);
  static const Color manualColor  = Color(0xFF10B981);
  static const Color cameraColor  = Color(0xFFF59E0B);

  // Warning messages
  static const Map<int, String> _levelMessages = {
    1: "Warning: Usage above 170 units.",
    2: "Warning: Usage above 180 units.",
    3: "Warning: Usage above 190 units.",
    4: "Meter frozen! Usage above 200 units.",
  };

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<MeterProvider>()
          .loadMonthly(widget.meter.id, selectedYear, selectedMonth);
    });
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blinkAnimation =
        Tween<double>(begin: 1.0, end: 0.3).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _readingController.dispose();
    _postingDayController.dispose();
    _postingMonthController.dispose();
    _postingYearController.dispose();
    super.dispose();
  }

  Future<void> _setStartReading() async {
    _readingController.clear();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Start Reading'),
        content: TextField(
          controller: _readingController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Initial units'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(_readingController.text);
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Text("Set"),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await context
            .read<MeterProvider>()
            .setStart(widget.meter.id, selectedYear, selectedMonth, result);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Start reading set")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: alertColor),
        );
      }
    }
  }

  Future<void> _addReadingManually() async {
    _readingController.clear();
    _postingDayController.clear();
    _postingMonthController.clear();
    _postingYearController.clear();
    final prov = context.read<MeterProvider>();

    final res = await showDialog<List<Object>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Reading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _readingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Reading Value'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postingDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Day'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Month'),
                    value: null, // no pre‐selection
                    items: prov.getMonthNames().asMap().entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key + 1,       // 1..12
                        child: Text(e.value),   // January, February, …
                      );
                    }).toList(),
                    onChanged: (sel) {
                      _postingMonthController.text = sel.toString();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _postingYearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Posting date is optional. Leave all empty for today's date.\nIf you fill any field, you must fill all three.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final readingVal = double.tryParse(_readingController.text);
              final dayStr = _postingDayController.text.trim();
              final monthStr = _postingMonthController.text.trim();
              final yearStr = _postingYearController.text.trim();

              final anyFilled = dayStr.isNotEmpty || monthStr.isNotEmpty || yearStr.isNotEmpty;
              final allFilled = dayStr.isNotEmpty && monthStr.isNotEmpty && yearStr.isNotEmpty;



              if (readingVal == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid reading value")),
                );
                return;
              }
              if (anyFilled && !allFilled) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Either leave all date fields empty or fill all three")),
                );
                return;
              }
              if (allFilled) {
              final day   = int.tryParse(dayStr);
              final month = int.tryParse(monthStr);
              final year  = int.tryParse(yearStr);

              if (day == null || month == null || year == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text("Day, month, and year must be numeric")),
              );
              return;
              }
              if (year <= 0) {
              ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text("Year must be greater than 0")),
              );
              return;
              }
              if (month < 1 || month > 12) {
              ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text("Month must be between 1 and 12")),
              );
              return;
              }
              // compute this month’s max day:
              final lastDay = DateTime(year, month + 1, 0).day;
              if (day < 1 || day > lastDay) {
              ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text("Day must be between 1 and $lastDay")),
              );
              return;
              }
              }

              Navigator.pop(ctx, <Object>[readingVal, dayStr, monthStr, yearStr]);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (res == null) return;

    final readingVal = res[0] as double;
    final dayStr = (res[1] as String);
    final monthStr = (res[2] as String);
    final yearStr = (res[3] as String);
    const name = "ashar"; // default per your spec

    // Determine postingDate
    DateTime postingDate;
    if (dayStr.isEmpty && monthStr.isEmpty && yearStr.isEmpty) {
      postingDate = DateTime.now();
    } else {
      final d = int.tryParse(dayStr);
      final m = _monthStringToInt(monthStr);
      final y = int.tryParse(yearStr);
      if (d == null || m == null || y == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid posting date"), backgroundColor: alertColor),
        );
        return;
      }
      // preserve current time-of-day
      final now = DateTime.now();
      postingDate = DateTime(y, m, d, now.hour, now.minute, now.second);
    }

    // Build the ISO strings
    final now = DateTime.now();
    final isoReadingDate =
        '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isoPostingDate =
        '${postingDate.year}-${postingDate.month.toString().padLeft(2, '0')}-${postingDate.day.toString().padLeft(2, '0')}';

    try {
      await context.read<MeterProvider>().addEntry(
        widget.meter.id,
        selectedYear,
        selectedMonth,
        name,
        readingVal,
        isoPostingDate,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reading added")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: alertColor),
      );
    }
  }


  int? _monthStringToInt(String month) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final idx = months.indexWhere((m) => m.toLowerCase() == month.toLowerCase());
    return idx == -1 ? null : idx + 1;
  }

  void _showAddReadingOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Add Reading",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: manualColor),
              icon: const Icon(Icons.edit),
              label: const Text("Enter Manually"),
              onPressed: () {
                Navigator.pop(context);
                _addReadingManually();
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: cameraColor),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture via Camera"),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("Coming soon...")));
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<MeterProvider>();
    final entries = prov.getEntries(widget.meter.id, selectedYear, selectedMonth) ?? [];
    final start   = prov.getStart(widget.meter.id, selectedYear, selectedMonth) ?? 0.0;
    final usage   = entries.isNotEmpty ? entries.first.reading - start : 0.0;
    final level   = prov.getLevel(widget.meter.id, selectedYear, selectedMonth);
    final hasStart = prov.hasStart(widget.meter.id, selectedYear, selectedMonth);
    final isFrozen = usage > 200;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Text(
          widget.meter.name,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          if (level > 0)
            AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (ctx, _) => Opacity(
                opacity: _blinkAnimation.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: alertColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)],
                  ),
                  padding: const EdgeInsets.all(14),
                  width: double.infinity,
                  child: Text(
                    _levelMessages[level]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Month & Year
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        decoration: _inputStyle('Month'),
                        value: selectedMonth,
                        items: prov.getMonthNames().asMap().entries.map((e) {
                          return DropdownMenuItem(value: e.key + 1, child: Text(e.value));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => selectedMonth = v);
                            prov.loadMonthly(widget.meter.id, selectedYear, selectedMonth);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$selectedYear',
                        decoration: _inputStyle('Year'),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (v) {
                          final y = int.tryParse(v);
                          if (y != null) {
                            setState(() => selectedYear = y);
                            prov.loadMonthly(widget.meter.id, selectedYear, selectedMonth);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoCard("Start", '${start.toStringAsFixed(1)}'),
                    _infoCard("Usage", '${usage.toStringAsFixed(1)}'),
                  ],
                ),
                const SizedBox(height: 16),
                // Set/Add button (instant, no FutureBuilder)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(hasStart ? Icons.add : Icons.flag),
                    label: Text(hasStart ? 'Add Reading' : 'Set Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasStart
                          ? (isFrozen ? Colors.grey : primaryColor)
                          : manualColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: hasStart
                        ? (isFrozen
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Meter has been frozen!")),
                    )
                        : _showAddReadingOptions)
                        : _setStartReading,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Entries list with delete icon
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (ctx, idx) {
                final e = entries[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.bolt, color: primaryColor),
                    title: Text(
                      '${e.reading.toStringAsFixed(1)} units',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(e.time)} '
                          'at ${DateFormat('hh:mm:ss a').format(e.time)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Entry?'),
                                content: const Text('Are you sure you want to delete this reading?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await context.read<MeterProvider>().removeEntry(
                                  widget.meter.id,
                                  selectedYear,
                                  selectedMonth,
                                  e.id,
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Entry deleted')));
                              } catch (err) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Delete failed: $err')));
                              }
                            }
                          },
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
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

  Widget _infoCard(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}