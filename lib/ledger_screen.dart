import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bill_detail_screen.dart';
import 'credit_history_screen.dart';
import 'services/user_scope.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final List<String> _allCustomers = [];
  List<String> _filteredCustomers = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _customerController.addListener(_filterCustomers);
  }

  Future<void> _loadCustomers() async {
    final uid = currentUserId();
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('customers')
        .where('ownerId', isEqualTo: uid)
        .get();
    _allCustomers
      ..clear()
      ..addAll(
        snapshot.docs
            .where((doc) => (doc.data()['isDeleted'] ?? false) != true)
            .map((doc) => (doc['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty),
      );
    _filterCustomers();
  }

  void _filterCustomers() {
    final query = _customerController.text.toLowerCase().trim();
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = [];
      } else {
        _filteredCustomers = _allCustomers
            .where((name) => name.toLowerCase().contains(query))
            .take(8)
            .toList();
      }
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String _dateKey(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _addManualCredit() async {
    final uid = currentUserId();
    if (uid == null) return;
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
      "ownerId": uid,
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
      _filteredCustomers = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual credit added')),
    );
  }

  @override
  void dispose() {
    _customerController.removeListener(_filterCustomers);
    _customerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  DateTime? _tryParseDateTime(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  // String _formatDate(DateTime? dt) {
  //   if (dt == null) return '-';
  //   String two(int v) => v.toString().padLeft(2, '0');
  //   return '${two(dt.day)}-${two(dt.month)}-${dt.year}';
  // }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $amPm';
  }

  Future<void> _markEntryPaid(
    QueryDocumentSnapshot item,
    Map<String, dynamic> rawItem,
  ) async {
    final originalDate = (rawItem['date'] ?? '').toString();
    final todayStr = _todayKey();
    final entryDate =
        originalDate.length >= 10 ? originalDate.substring(0, 10) : '';
    final paidSameDay = entryDate == todayStr;
    final paidAmount = (rawItem['pendingAmount'] ?? 0).toDouble().abs();

    await FirebaseFirestore.instance.collection('ledger').doc(item.id).update({
      "pendingAmount": 0,
      "status": "paid",
      "paidAt": DateTime.now().toString(),
      "paidSameDay": paidSameDay,
      "paidAmount": paidAmount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _dateKey(_selectedDate); // yyyy-mm-dd
    final selectedDatePill = (() {
      final parts = selectedKey.split('-');
      if (parts.length != 3) return selectedKey;
      final yyyy = parts[0];
      final mm = parts[1];
      final dd = parts[2];
      return '$dd-$mm-$yyyy';
    })();

    Future<void> openHistory() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1),
      );
      if (picked == null || !context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreditHistoryScreen(selectedDate: picked),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Daily Ledger'),
            const SizedBox(height: 4),
            Text(
              selectedDatePill,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.indigo.shade700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: openHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('History'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 0) {
            // Swipe right => previous day
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            });
          } else if (velocity < 0) {
            // Swipe left => next day (up to today)
            final todayDate = DateTime.now();
            final todayOnly =
                DateTime(todayDate.year, todayDate.month, todayDate.day);
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
          all.sort((a, b) {
            final ad = (a['date'] ?? '').toString();
            final bd = (b['date'] ?? '').toString();
            return bd.compareTo(ad);
          });

          final data = all.where((doc) {
            final dateStr = (doc['date'] ?? '').toString();
            final isSelectedDay =
                dateStr.length >= 10 && dateStr.substring(0, 10) == selectedKey;
            final raw = doc.data() as Map<String, dynamic>;
            final status = (raw['status'] ?? '').toString();
            final pending = (raw['pendingAmount'] ?? 0).toDouble();

            // Daily Ledger should show today's credit activity:
            // - billing credit entries
            // - manual credit entries added from this Daily Ledger screen
            // Exclude customer-report manual borrow/deposit entries.
            final isCustomerReportManual = status.startsWith('manual');
            final isPendingCredit = pending > 0 && status == 'pending';
            final isPaidCredit = status == 'paid';
            return isSelectedDay &&
                !isCustomerReportManual &&
                (isPendingCredit || isPaidCredit);
          }).toList();

          if (data.isEmpty) {
            // Still show header + manual add even if no data for today
            // so user can add manual credits.
          }

          return Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Add Credit',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerController,
                        decoration: InputDecoration(
                          hintText: 'Customer Name',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: const Icon(Icons.person,
                              size: 18, color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Credit Amount',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(
                                  Icons.currency_rupee,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _addManualCredit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 22),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_customerController.text.trim().isNotEmpty &&
                  _filteredCustomers.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 170),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final name = _filteredCustomers[index];
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          onTap: () {
                            setState(() {
                              _customerController.text = name;
                              _filteredCustomers = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text('No credit entries for selected day'))
                    : Builder(
                        builder: (context) {
                          final grouped = <String, List<QueryDocumentSnapshot>>{};
                          for (final doc in data) {
                            final customer = (doc['customer'] ?? '').toString();
                            if (customer.isEmpty) continue;
                            grouped.putIfAbsent(customer, () => []).add(doc);
                          }
                          final customers = grouped.keys.toList()
                            ..sort(
                              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                            );

                          return ListView.builder(
                            itemCount: customers.length,
                            itemBuilder: (context, index) {
                              final customer = customers[index];
                              final entries = grouped[customer]!;
                              entries.sort((a, b) {
                                final ad = (a['date'] ?? '').toString();
                                final bd = (b['date'] ?? '').toString();
                                return bd.compareTo(ad);
                              });
                              final total = entries.fold<double>(
                                0,
                                (totalSoFar, e) =>
                                    totalSoFar +
                                    (e['pendingAmount'] ?? 0).toDouble(),
                              );

                              return Card(
                                margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  backgroundColor:
                                      Colors.indigo.withValues(alpha: 0.05),
                                  collapsedBackgroundColor: Colors.white,
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
                                    'Total: ₹${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  childrenPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  children: [
                                    ...entries.map((item) {
                                      final rawItem =
                                          item.data() as Map<String, dynamic>;
                                      final dateRaw =
                                          (rawItem['date'] ?? '').toString();
                                      final dt = _tryParseDateTime(dateRaw);
                                      final status =
                                          (rawItem['status'] ?? '').toString();
                                      final isPaid = status == 'paid';
                                      final billId =
                                          (rawItem['billId'] ?? '').toString().trim();
                                      final amount = (isPaid
                                              ? (rawItem['paidAmount'] ??
                                                      rawItem['billAmount'] ??
                                                      rawItem['pendingAmount'] ??
                                                      0)
                                              : (rawItem['pendingAmount'] ?? 0))
                                          .toDouble()
                                          .abs();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 2,
                                        ),
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        billId.isEmpty
                                                            ? Text(
                                                                'No Bill',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w500,
                                                                  color: isPaid
                                                                      ? Colors.grey
                                                                          .shade500
                                                                      : Colors.grey
                                                                          .shade600,
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
                                                                    TextButton
                                                                        .styleFrom(
                                                                  padding:
                                                                      EdgeInsets.zero,
                                                                  minimumSize:
                                                                      Size.zero,
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
                                                          _formatTime(dt),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
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
                                                  SizedBox(
                                                    height: 30,
                                                    child: OutlinedButton(
                                                      onPressed: () async {
                                                        final confirmed =
                                                            await showDialog<bool>(
                                                                  context: context,
                                                                  builder:
                                                                      (dialogCtx) =>
                                                                          AlertDialog(
                                                                    title:
                                                                        const Text(
                                                                      'Confirm Payment Received?',
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () =>
                                                                            Navigator.pop(
                                                                          dialogCtx,
                                                                          false,
                                                                        ),
                                                                        child:
                                                                            const Text(
                                                                          'Cancel',
                                                                        ),
                                                                      ),
                                                                      ElevatedButton(
                                                                        onPressed: () =>
                                                                            Navigator.pop(
                                                                          dialogCtx,
                                                                          true,
                                                                        ),
                                                                        child:
                                                                            const Text(
                                                                          'Yes',
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ) ??
                                                                false;
                                                        if (!confirmed) return;

                                                        await _markEntryPaid(
                                                          item,
                                                          rawItem,
                                                        );

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
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.indigo.shade50,
                                                        side: BorderSide(
                                                          color:
                                                              Colors.indigo.shade100,
                                                        ),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  12),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Receive',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.indigo,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Due',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            '₹${total.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: total <= 0
                                            ? null
                                            : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogCtx) =>
                                                        AlertDialog(
                                                          title: const Text(
                                                            'Confirm Payment Received?',
                                                          ),
                                                          content: Text(
                                                            'Mark all pending credits as paid for $customer?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                dialogCtx,
                                                                false,
                                                              ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                dialogCtx,
                                                                true,
                                                              ),
                                                              child: const Text(
                                                                'Yes',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  ) ??
                                                  false;
                                          if (!confirmed) return;

                                          for (final e in entries) {
                                            final raw = e.data()
                                                as Map<String, dynamic>;
                                            final status =
                                                (raw['status'] ?? '').toString();
                                            final pendingAmount =
                                                (raw['pendingAmount'] ?? 0)
                                                    .toDouble();
                                            if (status == 'pending' &&
                                                pendingAmount > 0) {
                                              await _markEntryPaid(e, raw);
                                            }
                                          }

                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Full amount received for $customer',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.check_circle,
                                            size: 18),
                                        label: const Text(
                                          'Settle Full Amount',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.indigo.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}