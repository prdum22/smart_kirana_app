import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'customer_report_screen.dart';
import 'deleted_customers_screen.dart';
import 'services/user_scope.dart';

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

  Future<bool> _confirmDelete(BuildContext context, String customerName) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this customer?'),
            content: Text('Soft delete "$customerName"?'),
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

  Future<void> _softDeleteCustomer(String customerName) async {
    final uid = currentUserId();
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .where('ownerId', isEqualTo: uid)
        .where('name', isEqualTo: customerName)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(snap.docs.first.id)
        .update({
      'isDeleted': true,
      'deletedAt': DateTime.now().toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeletedCustomersScreen()),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Deleted'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .where('ownerId', isEqualTo: currentUserId())
            .snapshots(),
        builder: (context, customersSnap) {
          if (!customersSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeCustomers = <String>{};
          for (final doc in customersSnap.data!.docs) {
            final raw = doc.data() as Map<String, dynamic>;
            final isDeleted = (raw['isDeleted'] ?? false) == true;
            if (isDeleted) continue;
            final name = (raw['name'] ?? '').toString().trim();
            if (name.isNotEmpty) activeCustomers.add(name);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ledger')
                .where('ownerId', isEqualTo: currentUserId())
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.docs;
              if (data.isEmpty && activeCustomers.isEmpty) {
                return const Center(child: Text('No Customers Found / कोई ग्राहक नहीं'));
              }

              final Map<String, double> customerTotals = {};
              // Initialize all known active customers with 0 balance
              for (final c in activeCustomers) {
                customerTotals[c] = 0.0;
              }
              
              final now = DateTime.now();
              String two(int v) => v.toString().padLeft(2, '0');
              final todayKey = '${now.year}-${two(now.month)}-${two(now.day)}';
              for (final doc in data) {
                final raw = doc.data() as Map<String, dynamic>;
            final customer = (doc['customer'] ?? '').toString();
            if (customer.trim().isEmpty || !activeCustomers.contains(customer)) {
              continue;
            }
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
                        separatorBuilder: (_, index) =>
                            Divider(height: 1, color: Colors.grey.shade300),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return InkWell(
                            onLongPress: () async {
                              final ok =
                                  await _confirmDelete(context, entry.key);
                              if (!ok) return;
                              await _softDeleteCustomer(entry.key);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Customer deleted'),
                                ),
                              );
                            },
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddCustomerDialog(BuildContext context) async {
    final controller = TextEditingController();
    final uid = currentUserId();
    if (uid == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer / नया ग्राहक'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Customer Name / नाम',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              
              Navigator.pop(ctx);
              
              // Check if currently exists
              final snap = await FirebaseFirestore.instance
                  .collection('customers')
                  .where('ownerId', isEqualTo: uid)
                  .where('name', isEqualTo: name)
                  .get();
                  
              if (snap.docs.isEmpty) {
                await FirebaseFirestore.instance.collection('customers').add({
                  "ownerId": uid,
                  "name": name,
                  "isDeleted": false,
                  "createdAt": DateTime.now().toString(),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer Added! ✅')),
                  );
                }
              } else {
                // If it already exists but might be soft deleted, restore it
                final doc = snap.docs.first;
                final data = doc.data();
                if (data['isDeleted'] == true) {
                  await FirebaseFirestore.instance.collection('customers').doc(doc.id).update({
                    "isDeleted": false,
                  });
                   if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer Restored! ✅')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer already exists!')),
                    );
                  }
                }
              }
            },
            child: const Text('Add / जोड़ें'),
          ),
        ],
      ),
    );
  }
}
