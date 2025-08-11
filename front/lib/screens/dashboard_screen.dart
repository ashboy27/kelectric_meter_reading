// lib/screens/dashboard_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meter_provider.dart';
import '../services/api_service.dart';
import 'meter_detail_screen.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<String> quotes = const [
    "Faith is love taking the form of aspiration.",
    "You can’t cross the sea merely by standing and staring at the water.",
    "No bird soars too high if he soars with his own wings.",
    "Don’t judge each day by the harvest you reap but by the seeds that you plant.",
    "I believe there’s an inner power that makes winners or losers. And the winners are the ones who really listen to the truth of their hearts.",
    "It is our attitude at the beginning of a difficult task which, more than anything else, will affect its successful outcome.",
    "Think like a queen. A queen is not afraid to fail. Failure is another stepping stone to greatness.",
    "Keep your feet on the ground, but let your heart soar as high as it will. Refuse to be average or to surrender to the chill of your spiritual environment.",
    "I hated every minute of training, but I said, ‘Don’t quit. Suffer now and live the rest of your life as a champion.’",
    "Don’t stop when you’re tired, stop when you’re done.",
    "All our dreams can come true, if we have the courage to pursue them.",
    "Don’t limit yourself. Many people limit themselves to what they think they can do. You can go as far as your mind lets you. What you believe, remember, you can achieve.",
    "Only the paranoid survive.",
    "It’s hard to beat a person who never gives up.",
    "I wake up every morning and think to myself, ‘How far can I push this company in the next 24 hours?’",
    "Write it. Shoot it. Publish it. Crochet it. Sauté it. Whatever. MAKE.",
    "If people are doubting how far you can go, go so far that you can’t hear them anymore.",
    "Fairy tales are more than true: not because they tell us that dragons exist, but because they tell us that dragons can be beaten.",
    "Everything you can imagine is real.",
    "Do one thing every day that scares you.",
    "Life is about making an impact, not making an income.",
    "Whatever the mind of man can conceive and believe, it can achieve.",
    "Strive not to be a success, but rather to be of value.",
    "Two roads diverged in a wood, and I—I took the one less traveled by, And that has made all the difference.",
    "I attribute my success to this: I never gave or took any excuse.",
    "You miss 100% of the shots you don’t take.",
    "The most difficult thing is the decision to act, the rest is merely tenacity.",
    "Every strike brings me closer to the next home run.",
    "Definiteness of purpose is the starting point of all achievement.",
    "Life isn’t about getting and having, it’s about giving and being.",
    "Life is what happens to you while you’re busy making other plans.",
    "We become what we think about.",
    "The most common way people give up their power is by thinking they don’t have any.",
    "The mind is everything. What you think you become.",
    "An unexamined life is not worth living.",
    "Eighty percent of success is showing up.",
    "Your time is limited, so don’t waste it living someone else’s life.",
    "Winning isn’t everything, but wanting to win is.",
    "I am not a product of my circumstances. I am a product of my decisions.",
    "You can never cross the ocean until you have the courage to lose sight of the shore."
  ];

  String currentQuote = "";

  @override
  void initState() {
    super.initState();
    _setRandomQuote();
  }

  void _setRandomQuote() {
    final random = Random();
    setState(() {
      currentQuote = quotes[random.nextInt(quotes.length)];
    });
  }

  Future<void> _handleRefresh(MeterProvider prov) async {
    await prov.loadSummary();
    _setRandomQuote();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MeterProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meters'),
        centerTitle: true,
        elevation: 2,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.meters.isEmpty
          ? const Center(child: Text('No meters to display.'))
          : RefreshIndicator(
        onRefresh: () => _handleRefresh(prov),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _OverallSummaryCard(usage: prov.homeCurrentMonth),
            const SizedBox(height: 24),
            Text(
              'Your Meters',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.58,
              ),
              itemCount: prov.meters.length,
              itemBuilder: (ctx, i) => _MeterTile(meter: prov.meters[i]),
            ),
            const SizedBox(height: 24),
            // Motivational Quote Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, color: Colors.indigo, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentQuote,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: Colors.indigo[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallSummaryCard extends StatelessWidget {
  final double usage;
  const _OverallSummaryCard({required this.usage});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.bar_chart, size: 32, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This Month's Usage",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${usage.toStringAsFixed(1)} units',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  final meter;
  const _MeterTile({Key? key, required this.meter}) : super(key: key);

  void _showDownloadConfirmation(BuildContext context, String meterId,String meterName) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirm Download',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to download data for $meterName meter for the past year?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Download'),
              onPressed: () async {
                Navigator.of(ctx).pop(); // close dialog
                final filePath = await ApiService().downloadMeterExcel(meterId,meterName);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Excel file for $meterName downloaded successfully at $filePath !')),
                );
              },
            ),
          ],
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MeterDetailScreen(meter: meter)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.electrical_services, size: 40, color: Colors.indigo[700]),
              const SizedBox(height: 8),
              Text(
                meter.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Expanded section for the units info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${meter.totalUnits.toStringAsFixed(1)} units',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This Month',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${meter.currentMonthUnits.toStringAsFixed(1)} units',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.indigo,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Button pinned to bottom
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () {
                    _showDownloadConfirmation(context, meter.id,meter.name);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




}
