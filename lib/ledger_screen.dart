import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  String _todayKey() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _addManualCredit() async {
    final customer = _customerController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (customer.isEmpty || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer and amount')),
      );
      return;
    }

    final now = DateTime.now().toString();

    await FirebaseFirestore.instance.collection('ledger').add({
      "customer": customer,
      "billAmount": amount,
      "pendingAmount": amount,
      "status": "pending",
      "date": now,
      "isManual": true,
    });

    if (!mounted) return;
    setState(() {
      _customerController.clear();
      _amountController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual credit added')),
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayKey();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Ledger'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ledger')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!.docs.toList();
          all.sort((a, b) {
            final ad = (a['date'] ?? '').toString();
            final bd = (b['date'] ?? '').toString();
            return bd.compareTo(ad);
          });

          final data = all.where((doc) {
            final dateStr = (doc['date'] ?? '').toString();
            final isToday =
                dateStr.length >= 10 && dateStr.substring(0, 10) == today;
            final raw = doc.data() as Map<String, dynamic>;
            final status = (raw['status'] ?? '').toString();

            // Daily Ledger should show today's credit activity:
            // - billing credit entries
            // - manual credit entries added from this Daily Ledger screen
            // Exclude customer-report manual borrow/deposit entries.
            final isCustomerReportManual = status.startsWith('manual');
            return isToday && !isCustomerReportManual;
          }).toList();

          if (data.isEmpty) {
            // Still show header + manual add even if no data for today
            // so user can add manual credits.
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Today: $today',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Add Credit',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customerController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Credit Amount',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _addManualCredit,
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text('No entries for today'))
                    : ListView.builder(
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
                                        '₹${(item['pendingAmount'] ?? 0).toDouble().toStringAsFixed(2)}',
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
                                                  final originalDate =
                                                      (item['date'] ?? '')
                                                          .toString();
                                                  final todayStr = _todayKey();
                                                  final entryDate = originalDate
                                                              .length >=
                                                          10
                                                      ? originalDate
                                                          .substring(0, 10)
                                                      : '';
                                                  final paidSameDay =
                                                      entryDate == todayStr;
                                                  final paidAmount = (item[
                                                                  'pendingAmount'] ??
                                                              0)
                                                          .toDouble()
                                                          .abs();

                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('ledger')
                                                      .doc(item.id)
                                                      .update({
                                                    "pendingAmount": 0,
                                                    "status": "paid",
                                                    "paidAt":
                                                        DateTime.now().toString(),
                                                    "paidSameDay": paidSameDay,
                                                    "paidAmount": paidAmount,
                                                  });

                                                  if (!context.mounted) return;
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
                                            style:
                                                const TextStyle(fontSize: 10),
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