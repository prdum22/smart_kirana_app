import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'bill_detail_screen.dart';
import 'services/user_scope.dart';

class DailyReportScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const DailyReportScreen({super.key, this.selectedDate});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
  }

  String _dateKey(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}'; // yyyy-mm-dd
  }

  String _dateLabel(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}'; // dd-mm-yyyy
  }

  String _timeLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final hour24 = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      return '$hour12:$minute $amPm';
    } catch (_) {
      return '-';
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this entry?'),
            content: const Text('This will permanently delete the bill.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _deleteBillAndLinkedLedger(String billId) async {
    final uid = currentUserId();
    if (uid == null) return;
    // 1) Delete any linked ledger entries created for this bill (credit bills)
    final ledgerSnap = await FirebaseFirestore.instance
        .collection('ledger')
        .where('ownerId', isEqualTo: uid)
        .where('billId', isEqualTo: billId)
        .get();
    for (final doc in ledgerSnap.docs) {
      await FirebaseFirestore.instance.collection('ledger').doc(doc.id).delete();
    }

    // 2) Delete bill itself (removes from history + report)
    await FirebaseFirestore.instance.collection('bills').doc(billId).delete();
  }

  Future<void> _openHistoryPicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final key = _dateKey(_selectedDate);
    final label = _dateLabel(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          TextButton.icon(
            onPressed: _openHistoryPicker,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('History'),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 0) {
            // Swipe right => previous day
            setState(() {
              _selectedDate =
                  _selectedDate.subtract(const Duration(days: 1));
            });
          } else if (velocity < 0) {
            // Swipe left => next day (up to today)
            final today = DateTime.now();
            final todayOnly = DateTime(today.year, today.month, today.day);
            final currentOnly = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            );
            if (!currentOnly.isAtSameMomentAs(todayOnly)) {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            }
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    'S.No',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Expanded(
                //   flex: 3,
                //   child: Text(
                //     'Name',
                //     style: TextStyle(fontWeight: FontWeight.bold),
                //   ),
                // ),
                SizedBox(
                  width: 72,
                  child: Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'Bill',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
            Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (currentUserId() == null)
                  ? null
                  : FirebaseFirestore.instance
                        .collection('bills')
                        .where('ownerId', isEqualTo: currentUserId())
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!.docs.toList();
                final filtered = all.where((doc) {
                  final raw = doc.data() as Map<String, dynamic>;
                  final dateStr = (raw['date'] ?? '').toString();
                  return dateStr.length >= 10 && dateStr.substring(0, 10) == key;
                }).toList();

                filtered.sort((a, b) {
                  final ad = ((a.data() as Map<String, dynamic>)['date'] ?? '')
                      .toString();
                  final bd = ((b.data() as Map<String, dynamic>)['date'] ?? '')
                      .toString();
                  return ad.compareTo(bd); // earliest first
                });

                double totalSales = 0;
                for (final doc in filtered) {
                  final raw = doc.data() as Map<String, dynamic>;
                  totalSales += (raw['finalTotal'] ?? 0).toDouble();
                }

                if (filtered.isEmpty) {
                  return _ReportListWithFooter(
                    totalSales: totalSales,
                    child: const Center(child: Text('No bills for this date')),
                  );
                }

                return _ReportListWithFooter(
                  totalSales: totalSales,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) =>
                        Divider(height: 1, color: Colors.grey.shade300),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final raw = doc.data() as Map<String, dynamic>;
                      final customer = (raw['customer'] ?? '').toString();
                      final dateStr = (raw['date'] ?? '').toString();
                      final time = _timeLabel(dateStr);
                      final amount = (raw['finalTotal'] ?? 0).toDouble();
                      final paymentType =
                          (raw['paymentType'] ?? 'Paid').toString();
                      final isPaid = paymentType.toLowerCase() != 'credit';

                      return InkWell(
                        onLongPress: () async {
                          final ok = await _confirmDelete(context);
                          if (!ok) return;
                          await _deleteBillAndLinkedLedger(doc.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Entry deleted')),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 42,
                                child: Text('${index + 1}'),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  customer,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(time),
                              ),
                              SizedBox(
                                width: 64,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BillDetailScreen(billId: doc.id),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Bill',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 86,
                                child: Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  isPaid ? 'PAID' : 'CREDIT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isPaid ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportListWithFooter extends StatelessWidget {
  final Widget child;
  final double totalSales;

  const _ReportListWithFooter({
    required this.child,
    required this.totalSales,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(
            "Today's Sales: ₹${totalSales.toStringAsFixed(2)}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

