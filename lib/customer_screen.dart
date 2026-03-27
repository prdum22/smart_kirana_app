import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'customer_report_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ledger').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.docs;
          if (data.isEmpty) {
            return const Center(child: Text('No Customer Ledger Data'));
          }

          final Map<String, double> customerTotals = {};
          final now = DateTime.now();
          String two(int v) => v.toString().padLeft(2, '0');
          final todayKey = '${now.year}-${two(now.month)}-${two(now.day)}';
          for (final doc in data) {
            final raw = doc.data() as Map<String, dynamic>;
            final customer = (doc['customer'] ?? '').toString();
            final amount = (doc['pendingAmount'] ?? 0).toDouble();
            final status = (raw['status'] ?? '').toString();
            final dateStr = (raw['date'] ?? '').toString();
            final entryDateKey =
                dateStr.length >= 10 ? dateStr.substring(0, 10) : '';

            // Same-day pending credits belong to Daily Ledger first;
            // include them in customer section only from next day.
            final hideSameDayPendingCredit =
                amount > 0 && status == 'pending' && entryDateKey == todayKey;
            if (hideSameDayPendingCredit) {
              continue;
            }
            customerTotals[customer] = (customerTotals[customer] ?? 0) + amount;
          }

          final entries = customerTotals.entries
              .where(
                (entry) =>
                    _searchQuery.isEmpty ||
                    entry.key.toLowerCase().contains(_searchQuery),
              )
              .toList()
            ..sort(
              (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
            );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Customer',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.shade200,
                child: const Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'S.No',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Name Customer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Remaining',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('No customer found'))
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade300),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerReportScreen(
                                    customerName: entry.key,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text('${index + 1}'),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      '₹${entry.value.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }
}
