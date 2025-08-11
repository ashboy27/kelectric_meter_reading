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
  Future<void> _updateStartReading() async {
    _readingController.clear();

    final prov = context.read<MeterProvider>();
    final monthlyData = await prov.fetchMonthlyData(
      widget.meter.id,
      selectedYear,
      selectedMonth,
    );

    final entries = monthlyData['entries'] as List<Entry>;
    //entries.sort((a, b) => a.time.compareTo(b.time)); // Oldest first

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Start Reading'),
        content: TextField(
          controller: _readingController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Initial units'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
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
      // Validation before sending API request
      if (entries.isNotEmpty) {
        final oldestEntry = entries.last; // Because we sorted
        final formattedDate = DateFormat('dd MMM yyyy').format(oldestEntry.time);
        final formattedTime = DateFormat.jm().format(oldestEntry.time);
        if (result > oldestEntry.reading) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Invalid Start Reading",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Text(
                  "Start reading must be less than the oldest entry's reading "
                      "(${oldestEntry.reading}) recorded on "
                      "$formattedDate at $formattedTime.",
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }
      }

      // ✅ Passed validation → update
      try {
        await prov.setStart(widget.meter.id, selectedYear, selectedMonth, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Start reading set")),
        );
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
    final monthlyData = await prov.fetchMonthlyData(widget.meter.id, selectedYear, selectedMonth);
    final entries = monthlyData['entries'] as List<Entry>;
    //entries.sort((a, b) => a.time.compareTo(b.time));

    final startReading = monthlyData['start_reading'] as double? ?? 0.0;
    final res = await showDialog<List<Object>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Reading'),
        content: SizedBox(
          width: 400, // Set dialog width to prevent overflow
          child: Column(
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
                    flex: 2, // Give month dropdown more space
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Month'),
                      isExpanded: true,
                      value: _postingMonthController.text.isNotEmpty
                          ? int.tryParse(_postingMonthController.text)
                          : null,
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(_monthStringToInt(m - 1)),
                      ))
                          .toList(),
                      onChanged: (sel) {
                        if (sel != null) {
                          _postingMonthController.text = sel.toString();
                        }
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final readingVal = double.tryParse(_readingController.text);
              final dayStr = _postingDayController.text.trim();
              final monthStr = _postingMonthController.text.trim();
              final yearStr = _postingYearController.text.trim();
              final anyFilled = dayStr.isNotEmpty || monthStr.isNotEmpty || yearStr.isNotEmpty;
              final allFilled = dayStr.isNotEmpty && monthStr.isNotEmpty && yearStr.isNotEmpty;
              String? errorMessage;

              if (readingVal == null) {
                errorMessage = "Please enter a valid reading value";
              } else if (readingVal < 0) {
                errorMessage = "Reading Value cannot be negative";
              } else if (readingVal < 1.0) {
                errorMessage = "Reading Value must be at least 1.0";
              } else if (anyFilled && !allFilled) {
                errorMessage = "Either leave all date fields empty or fill all three";
              } else if (allFilled) {
                final day = int.tryParse(dayStr);
                final month = int.tryParse(monthStr);
                final year = int.tryParse(yearStr);

                if (day == null || month == null || year == null) {
                  errorMessage = "Day, month, and year must be numeric";
                } else if (year <= 0) {
                  errorMessage = "Year must be greater than 0";
                } else if (month < 1 || month > 12) {
                  errorMessage = "Month must be between 1 and 12";
                } else {
                  final lastDay = DateTime(year, month + 1, 0).day;
                  if (day < 1 || day > lastDay) {
                    errorMessage = "Day must be between 1 and $lastDay";
                  }
                }
              }

              if (errorMessage != null) {
                await showDialog(
                  context: ctx,
                  builder: (context) => AlertDialog(
                    title: const Text("Error"),
                    content: Text(errorMessage!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
                return;
              }

              Navigator.pop(ctx, <Object>[readingVal as double, dayStr, monthStr, yearStr]);
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
      final m = int.tryParse(monthStr);
      final y = int.tryParse(yearStr);
      if (d == null || m == null || y == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid posting date"), backgroundColor: alertColor),
        );
        return;
      }
      final now = DateTime.now();
      postingDate = DateTime(y, m, d,now.hour, now.minute, now.second);
    }
    //print("AHSARRRRRRRRRRRR $postingDate $selectedMonth $selectedYear");
    // Fetch monthly data for validation
    try {





      if(entries.isEmpty){

        // If no entries, we can safely add the first reading
        if (readingVal < startReading) {
          showStartReadingErrorDialog(
            context: context,
            enteredValue: readingVal,
            startReading: startReading,
          );
          return;
        }

      }

      else {



        Entry? justGreater;
        Entry? justSmaller;

        for (var e in entries.reversed) {
          if (e.time.isAfter(postingDate)) {
            justGreater = e;
            break; // first greater found
          }
          if (e.time.isBefore(postingDate)) {
            justSmaller = e; // keeps updating until the latest before
          }
        }

        if (justGreater != null && readingVal > justGreater.reading) {
          showReadingErrorDialog(
            context: context,
            readingValue: readingVal,
            minAllowed: justSmaller?.reading ?? startReading,
            minTime: justSmaller?.time,
            maxAllowed: justGreater.reading,
            maxTime: justGreater.time,
          );
          return;
        }

        // JUST SMALLER check
        final smallerValue = justSmaller?.reading ?? startReading;
        if (readingVal < smallerValue) {
          showReadingErrorDialog(
            context: context,
            readingValue: readingVal,
            minAllowed: justSmaller?.reading ?? startReading,
            minTime: justSmaller?.time,
            maxAllowed: justGreater?.reading,
            maxTime: justGreater?.time,
          );
          return;
        }



      }

      // Build the ISO strings


      final isoPostingDate =
          '${postingDate.year}-${postingDate.month.toString().padLeft(2, '0')}-${postingDate.day.toString().padLeft(2, '0')}';

      await prov.addEntry(
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
  String _monthStringToInt(int index) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[index];
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
                          return DropdownMenuItem(value: e.key + 1, child: Text(_monthStringToInt(e.key)));
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
                    _infoCard(
                      "Start",
                      '${start.toStringAsFixed(0)} units',
                      onEdit: () {
                        // Your edit function call here
                        _updateStartReading(); // Replace with your actual function name
                      },
                    ),
                    _infoCard("Usage", '${usage.toStringAsFixed(0)} units'),
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
                    leading: const Icon(Icons.bolt, color: primaryColor),
                    title: Text(
                      '${e.reading.toStringAsFixed(0)} units',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat.yMMMd().format(e.time)} at ${DateFormat('hh:mm:ss a').format(e.time)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Used: ${(e.reading - start).toStringAsFixed(0)} units',
                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ],
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
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete')),
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


// Updated _infoCard function with optional edit button
  Widget _infoCard(String title, String value, {VoidCallback? onEdit}) {
    return Column(
      children: [
        Container(
          height: 32, // Fixed height to ensure alignment
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(8), // Increases tap area
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void showReadingErrorDialog({required BuildContext context, required readingValue, required double minAllowed, DateTime? minTime, required double? maxAllowed, required DateTime? maxTime}) {



    final dateTimeFormat = DateFormat("dd MMM yyyy • hh:mm a");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              "Invalid Reading",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You entered: $readingValue",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (minAllowed != double.negativeInfinity)
                    Text(
                      "Min allowed: $minAllowed"
                          "${minTime != null ? " (${dateTimeFormat.format(minTime)})" : ""}",
                      style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                    ),
                  if (maxAllowed != null)
                    const SizedBox(height: 8),
                  if (maxAllowed != null)
                    Text(
                      "Max allowed: $maxAllowed"
                          "${maxTime != null ? " (${dateTimeFormat.format(maxTime)})" : ""}",
                      style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Please enter a value within the allowed range.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void showStartReadingErrorDialog({
    required BuildContext context,
    required double enteredValue,
    required double startReading,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(
            child:Text(
              "Invalid First Reading",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400, // 👈 Makes dialog wider
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You entered: $enteredValue",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(12),
                child: Text(
                  "Kia yar Ahsan Bhai! First reading must be greater than the start reading: $startReading",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }



}