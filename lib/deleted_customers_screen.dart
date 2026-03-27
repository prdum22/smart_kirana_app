import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'services/user_scope.dart';

class DeletedCustomersScreen extends StatelessWidget {
  const DeletedCustomersScreen({super.key});

  DateTime _twoMonthsAgo() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 2, now.day);
  }

  Future<void> _cleanupExpiredDeletes(List<QueryDocumentSnapshot> docs) async {
    final cutoff = _twoMonthsAgo();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deletedAtStr = (data['deletedAt'] ?? '').toString();
      if (deletedAtStr.isEmpty) continue;
      DateTime? deletedAt;
      try {
        deletedAt = DateTime.parse(deletedAtStr);
      } catch (_) {
        continue;
      }
      if (deletedAt.isBefore(cutoff)) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(doc.id)
            .delete();
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmText,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: message == null ? null : Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmText),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Customers'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .where('ownerId', isEqualTo: currentUserId())
            .where('isDeleted', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final ad = ((a.data() as Map<String, dynamic>)['deletedAt'] ?? '')
                .toString();
            final bd = ((b.data() as Map<String, dynamic>)['deletedAt'] ?? '')
                .toString();
            return bd.compareTo(ad);
          });

          // Best-effort cleanup (no backend cron): permanently delete
          // customers that were deleted > 2 months ago.
          _cleanupExpiredDeletes(docs);

          if (docs.isEmpty) {
            return const Center(child: Text('No deleted customers'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, index) =>
                Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString();
              final deletedAt = (data['deletedAt'] ?? '').toString();

              return ListTile(
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: deletedAt.isEmpty
                    ? null
                    : Text('Deleted at: ${deletedAt.substring(0, 10)}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Restore customer?',
                          message: 'Restore "$name" to active customers?',
                          confirmText: 'Restore',
                        );
                        if (!ok) return;
                        await FirebaseFirestore.instance
                            .collection('customers')
                            .doc(doc.id)
                            .update({
                          'isDeleted': false,
                          'deletedAt': FieldValue.delete(),
                        });
                      },
                      child: const Text('Restore'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Permanent delete?',
                          message:
                              'Delete "$name" forever? This cannot be undone.',
                          confirmText: 'Delete',
                        );
                        if (!ok) return;
                        await FirebaseFirestore.instance
                            .collection('customers')
                            .doc(doc.id)
                            .delete();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

