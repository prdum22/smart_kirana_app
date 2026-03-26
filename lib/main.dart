import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'billing_screen.dart';
import 'ledger_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartKiranaApp());
}

class SmartKiranaApp extends StatelessWidget {
  const SmartKiranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Kirana',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget buildButton(
    BuildContext context, {
    required IconData icon,
    required String englishText,
    required String hindiText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 8),
              Text(
                englishText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hindiText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title page coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Kirana / स्मार्ट किराना'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            buildButton(
              context,
              icon: Icons.receipt_long,
              englishText: 'New Bill',
              hindiText: 'नया बिल',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingScreen()),
                );
              },
            ),
            buildButton(
              context,
              icon: Icons.people,
              englishText: 'Customers',
              hindiText: 'ग्राहक',
              onTap: () => openPlaceholder(context, 'Customers'),
            ),
            buildButton(
              context,
              icon: Icons.book,
              englishText: 'Ledger',
              hindiText: 'उधार खाता',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LedgerScreen()),
                );
              },
            ),
            buildButton(
              context,
              icon: Icons.bar_chart,
              englishText: 'Daily Report',
              hindiText: 'रोज़ की रिपोर्ट',
              onTap: () => openPlaceholder(context, 'Daily Report'),
            ),
          ],
        ),
      ),
    );
  }
}
