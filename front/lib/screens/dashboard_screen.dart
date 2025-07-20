import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meter_provider.dart';
import 'meter_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MeterProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meters'),
        centerTitle: true,
        elevation: 0,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.meters.isEmpty
          ? const Center(child: Text('No meters yet'))
          : RefreshIndicator(
        onRefresh: prov.loadSummary,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _SummaryCard(usage: prov.homeCurrentMonth),
          const SizedBox(height: 24),
          Text('All Meters',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
            physics: const NeverScrollableScrollPhysics(),
            children: prov.meters
                .map((m) => _MeterTile(meter: m))
                .toList(),
          ),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double usage;
  const _SummaryCard({required this.usage});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          const Icon(Icons.bar_chart, size: 48, color: Colors.indigo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("This Month's Usage",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              Text('${usage.toStringAsFixed(1)} units',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.indigo)),
            ]),
          )
        ]),
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  final meter;
  const _MeterTile({Key? key, required this.meter}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MeterDetailScreen(meter: meter))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.electrical_services, size: 40, color: Colors.indigo),
            Text(meter.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Column(children: [
              Text('Total: ${meter.totalUnits.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text('Month: ${meter.currentMonthUnits.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }
}
