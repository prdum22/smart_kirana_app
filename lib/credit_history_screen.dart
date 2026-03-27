import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'bill_detail_screen.dart';
import 'services/user_scope.dart';

class CreditHistoryScreen extends StatelessWidget {
  final DateTime selectedDate;

  const CreditHistoryScreen({super.key, required this.selectedDate});

  String _dateKey(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}'; // yyyy-mm-dd
  }

  String _dateLabel(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}'; // dd-mm-yyyy
  }

  DateTime? _tryParseDateTime(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final key = _dateKey(selectedDate);
    final label = _dateLabel(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit History'),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (currentUserId() == null)
                  ? null
                  : FirebaseFirestore.instance
                        .collection('ledger')
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
                  final status = (raw['status'] ?? '').toString();
                  final pending = (raw['pendingAmount'] ?? 0).toDouble();
                  final dateStr = (raw['date'] ?? '').toString();
                  final entryKey =
                      dateStr.length >= 10 ? dateStr.substring(0, 10) : '';

                  // Only credit-related ledger entries for that date:
                  // - billing credit (status pending/paid, positive)
                  // - daily ledger manual credits (status pending/paid, positive)
                  // Exclude customer-report manual borrow/deposit.
                  final isCustomerReportManual = status.startsWith('manual');
                  final isCreditPending = status == 'pending' && pending > 0;
                  final isCreditPaid = status == 'paid';
                  return entryKey == key &&
                      !isCustomerReportManual &&
                      (isCreditPending || isCreditPaid);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No credit entries found'));
                }

                // Group by customer
                final grouped = <String, List<QueryDocumentSnapshot>>{};
                for (final doc in filtered) {
                  final customer = (doc['customer'] ?? '').toString();
                  if (customer.trim().isEmpty) continue;
                  grouped.putIfAbsent(customer, () => []).add(doc);
                }

                final customers = grouped.keys.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final entries = grouped[customer]!;

                    entries.sort((a, b) {
                      final ad =
                          ((a.data() as Map<String, dynamic>)['date'] ?? '')
                              .toString();
                      final bd =
                          ((b.data() as Map<String, dynamic>)['date'] ?? '')
                              .toString();
                      return bd.compareTo(ad);
                    });

                    double customerTotal = 0;
                    for (final e in entries) {
                      final raw = e.data() as Map<String, dynamic>;
                      final status = (raw['status'] ?? '').toString();
                      final isPaid = status == 'paid';
                      final amount = (isPaid
                              ? (raw['paidAmount'] ??
                                  raw['billAmount'] ??
                                  raw['pendingAmount'] ??
                                  0)
                              : (raw['pendingAmount'] ?? 0))
                          .toDouble()
                          .abs();
                      customerTotal += amount;
                    }

                    return Card(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        collapsedBackgroundColor: Colors.white,
                        backgroundColor: Colors.indigo.withValues(alpha: 0.05),
                        collapsedIconColor: Colors.indigo.shade600,
                        iconColor: Colors.indigo.shade600,
                        title: Text(
                          customer,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Total: ₹${customerTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          ...entries.map((item) {
                            final raw = item.data() as Map<String, dynamic>;
                            final status = (raw['status'] ?? '').toString();
                            final isPaid = status == 'paid';
                            final billId = (raw['billId'] ?? '')
                                .toString()
                                .trim();
                            final dateRaw = (raw['date'] ?? '').toString();
                            final dt = _tryParseDateTime(dateRaw);
                            final time = _formatTime(dt);
                            final amount = (isPaid
                                    ? (raw['paidAmount'] ??
                                        raw['billAmount'] ??
                                        raw['pendingAmount'] ??
                                        0)
                                    : (raw['pendingAmount'] ?? 0))
                                .toDouble()
                                .abs();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 2),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green.shade50
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long,
                                            size: 18,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              billId.isEmpty
                                                  ? Text(
                                                      'No Bill',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isPaid
                                                            ? Colors
                                                                .grey.shade500
                                                            : Colors
                                                                .grey.shade600,
                                                        fontSize: 13,
                                                      ),
                                                    )
                                                  : TextButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                BillDetailScreen(
                                                              billId: billId,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        padding: EdgeInsets.zero,
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                      child: const Text(
                                                        'View Bill',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.indigo,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                              const SizedBox(height: 4),
                                              Text(
                                                time,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isPaid
                                                      ? Colors.grey.shade500
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: isPaid
                                              ? Colors.green.shade700
                                              : Colors.red,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (isPaid)
                                        Chip(
                                          avatar: const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          label: const Text(
                                            'PAID',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor:
                                              Colors.green.shade50,
                                        )
                                      else
                                        Chip(
                                          avatar: const Icon(
                                            Icons.circle,
                                            size: 10,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            'CREDIT',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor: Colors.red.shade50,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '₹${customerTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
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

