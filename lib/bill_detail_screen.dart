import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BillDetailScreen extends StatelessWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Detail'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('bills').doc(billId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Bill not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final customer = (data['customer'] ?? '').toString();
          final dateStr = (data['date'] ?? '').toString();
          final paymentType = (data['paymentType'] ?? '').toString();
          final finalTotal = (data['finalTotal'] ?? 0).toDouble();
          final items = (data['items'] as List?) ?? [];

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: $customer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date & Time: $dateStr',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mode: $paymentType',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: ₹${finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? const Text('No items')
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item =
                                (items[index] as Map).cast<String, dynamic>();
                            final name = (item['name'] ?? '').toString();
                            final qty = (item['qty'] ?? 0).toDouble();
                            final unit = (item['unit'] ?? '').toString();
                            final rate = (item['rate'] ?? 0).toDouble();
                            final total = qty * rate;
                            return ListTile(
                              dense: true,
                              title: Text(name),
                              subtitle: Text(
                                  'Qty: $qty ${unit.isNotEmpty ? unit : ''}  •  Rate: ₹${rate.toStringAsFixed(2)}'),
                              trailing: Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

