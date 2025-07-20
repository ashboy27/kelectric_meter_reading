class Entry {
  final String id;         // NEW
  final DateTime date;
  final DateTime time;
  final double reading;
  //String name;

  Entry({
    required this.id,
    required this.date,
    required this.time,
    required this.reading,
  });

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,                                    // NEW
    date: DateTime.parse(j['date'] as String),
    time: DateTime.parse(j['time'] as String),
    reading: (j['reading'] as num).toDouble(),
    // name: j['posted_by'] as String,
  );
}
