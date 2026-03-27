import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bill_detail_screen.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String customerName;

  const CustomerHistoryScreen({super.key, required this.customerName});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2);
    final last = DateTime(now.year + 1);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  bool _inRange(DateTime d) {
    if (_fromDate == null || _toDate == null) return true;
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
    return (d.isAtSameMomentAs(from) || d.isAfter(from)) &&
        (d.isAtSameMomentAs(to) || d.isBefore(to));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} - History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _fromDate == null || _toDate == null
                          ? 'Filter by date'
                          : '${_fromDate!.toLocal().toString().substring(0, 10)} → ${_toDate!.toLocal().toString().substring(0, 10)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_fromDate != null || _toDate != null)
                  IconButton(
                    onPressed: _clearFilter,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear filter',
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date & Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Bill',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bills')
                  .where('customer', isEqualTo: widget.customerName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final ad = (a['date'] ?? '').toString();
                  final bd = (b['date'] ?? '').toString();
                  return bd.compareTo(ad); // latest first
                });

                final filtered = docs.where((doc) {
                  final dateStr = (doc['date'] ?? '').toString();
                  DateTime? d;
                  try {
                    d = DateTime.parse(dateStr);
                  } catch (_) {
                    return true;
                  }
                  return _inRange(d);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No records found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade300),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final dateStr = (data['date'] ?? '').toString();
                    String datePart = '';
                    String timePart = '';
                    if (dateStr.isNotEmpty) {
                      try {
                        final d = DateTime.parse(dateStr);
                        datePart = d.toLocal().toString().substring(0, 10);
                        timePart =
                            d.toLocal().toString().substring(11, 19); // HH:mm:ss
                      } catch (_) {
                        datePart = dateStr;
                      }
                    }
                    final paymentType =
                        (data['paymentType'] ?? '').toString().isEmpty
                            ? 'Paid'
                            : data['paymentType'].toString();
                    final amount =
                        (data['finalTotal'] ?? 0).toDouble().toStringAsFixed(2);

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BillDetailScreen(billId: doc.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    datePart,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (timePart.isNotEmpty)
                                    Text(
                                      timePart,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'Bill',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                paymentType,
                                style: TextStyle(
                                  color: paymentType == 'Credit'
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹$amount',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

