import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Udhar List / उधार सूची'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ledger')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.docs;

          if (data.isEmpty) {
            return const Center(
              child: Text('No Credit Data / कोई उधार नहीं'),
            );
          }

          Map<String, double> customerTotals = {};

          for (var doc in data) {
            final customer = doc['customer'].toString();
            final amount = (doc['pendingAmount'] ?? 0).toDouble();

            if (customerTotals.containsKey(customer)) {
              customerTotals[customer] = customerTotals[customer]! + amount;
            } else {
              customerTotals[customer] = amount;
            }
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: customerTotals.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${entry.key} → ₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(item['customer']),
                          subtitle: Text(
                            'Date: ${item['date'].toString().substring(0, 10)}\nStatus: ${item['status']}',
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${item['pendingAmount']}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: item['status'] == 'paid'
                                        ? null
                                        : () async {
                                            await FirebaseFirestore.instance
                                                .collection('ledger')
                                                .doc(item.id)
                                                .update({
                                              "pendingAmount": 0,
                                              "status": "paid",
                                            });

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Amount Received / भुगतान प्राप्त',
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      item['status'] == 'paid'
                                          ? 'Paid'
                                          : 'Receive',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}