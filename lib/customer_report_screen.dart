import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'customer_history_screen.dart';

class CustomerReportScreen extends StatelessWidget {
  final String customerName;

  const CustomerReportScreen({
    super.key,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customerName),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerHistoryScreen(customerName: customerName),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('History'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ledger')
            .where('customer', isEqualTo: customerName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading data: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('No ledger data for $customerName'),
            );
          }

          final borrowEntries = <Map<String, dynamic>>[];
          final depositEntries = <Map<String, dynamic>>[];
          double remaining = 0;
          final now = DateTime.now();
          String two(int v) => v.toString().padLeft(2, '0');
          final todayKey = '${now.year}-${two(now.month)}-${two(now.day)}';

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final pending = (data['pendingAmount'] ?? 0).toDouble();
            final dateStr = (data['date'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final entryDateKey =
                dateStr.length >= 10 ? dateStr.substring(0, 10) : '';

            // Borrow list rules:
            // - Billing credit + Daily Ledger manual credit are saved in ledger immediately.
            // - They should appear in customer borrow only from next day if still pending.
            // - Explicit customer manualBorrow entries should appear immediately.
            final hideSameDayPendingCredit =
                status == 'pending' && entryDateKey == todayKey;
            if (pending > 0 && !hideSameDayPendingCredit) {
              borrowEntries.add({
                'date': dateStr,
                'amount': pending,
              });
              remaining += pending;
              continue;
            }

            // Deposit list rules:
            // 1) Manual deposit entries (negative pending) always appear.
            if (pending < 0) {
              depositEntries.add({
                'date': dateStr,
                'amount': -pending,
              });
              remaining += pending;
              continue;
            }

            // 2) Paid credits that were NOT settled same day appear as deposit.
            if (pending == 0 && status == 'paid') {
              final paidSameDay = data['paidSameDay'] == true;
              if (!paidSameDay) {
                final paidAt = (data['paidAt'] ?? '').toString();
                final paidAmount = (data['paidAmount'] ?? data['billAmount'] ?? 0)
                    .toDouble()
                    .abs();
                depositEntries.add({
                  'date': paidAt.isNotEmpty ? paidAt : dateStr,
                  'amount': paidAmount,
                });
              }
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _showManualEntryDialog(
                          context,
                          customerName: customerName,
                          isBorrow: true,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Borrow'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _showManualEntryDialog(
                          context,
                          customerName: customerName,
                          isBorrow: false,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Deposit'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Borrow',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: borrowEntries.isEmpty
                                  ? const Center(
                                      child: Text('No borrow entries'),
                                    )
                                  : ListView.builder(
                                      itemCount: borrowEntries.length,
                                      itemBuilder: (context, index) {
                                        final entry = borrowEntries[index];
                                        final date =
                                            (entry['date'] ?? '').toString();
                                        final amount =
                                            (entry['amount'] ?? 0).toDouble();
                                        return ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 0,
                                          ),
                                          title: Text(
                                            date.length >= 10
                                                ? date.substring(0, 10)
                                                : date,
                                          ),
                                          trailing: Text(
                                            '₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deposit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: depositEntries.isEmpty
                                  ? const Center(
                                      child: Text('No deposit entries'),
                                    )
                                  : ListView.builder(
                                      itemCount: depositEntries.length,
                                      itemBuilder: (context, index) {
                                        final entry = depositEntries[index];
                                        final date =
                                            (entry['date'] ?? '').toString();
                                        final amount =
                                            (entry['amount'] ?? 0).toDouble();
                                        return ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 0,
                                          ),
                                          title: Text(
                                            date.length >= 10
                                                ? date.substring(0, 10)
                                                : date,
                                          ),
                                          trailing: Text(
                                            '₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey.shade200,
                child: Text(
                  'Remaining: ₹${remaining.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showManualEntryDialog(
  BuildContext context, {
  required String customerName,
  required bool isBorrow,
}) async {
  final controller = TextEditingController();
  final noteController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isBorrow ? 'Add Borrow' : 'Add Deposit'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter amount';
                  }
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(controller.text.trim());
              final now = DateTime.now().toString();

              if (!isBorrow) {
                final ledgerSnapshot = await FirebaseFirestore.instance
                    .collection('ledger')
                    .where('customer', isEqualTo: customerName)
                    .get();

                double outstanding = 0;
                for (final d in ledgerSnapshot.docs) {
                  final raw = d.data();
                  outstanding += (raw['pendingAmount'] ?? 0).toDouble();
                }

                if (outstanding <= 0 || amount > outstanding) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Deposit cannot exceed borrow (max ₹${outstanding > 0 ? outstanding.toStringAsFixed(2) : '0.00'})',
                        ),
                      ),
                    );
                  }
                  return;
                }
              }

              final pendingAmount = isBorrow ? amount : -amount;

              await FirebaseFirestore.instance.collection('ledger').add({
                'customer': customerName,
                'pendingAmount': pendingAmount,
                'billAmount': 0,
                'status': isBorrow ? 'manualBorrow' : 'manualDeposit',
                'date': now,
                'note': noteController.text.trim(),
                'isManual': true,
              });

              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

