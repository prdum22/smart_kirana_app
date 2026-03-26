import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

// bool isListening = false;

class _BillingScreenState extends State<BillingScreen> {
  List<String> customers = [];
  List<String> allItems = [];
  List<String> filteredItems = [];

  bool isListening = false;
  late stt.SpeechToText speech;
  bool _speechAvailable = false;
  bool _speechInitializing = false;

  String? selectedCustomer;
  String paymentType = 'Paid';

  final TextEditingController discountController = TextEditingController();
  final TextEditingController extraController = TextEditingController();
  final TextEditingController customerSearchController =
      TextEditingController();
  final TextEditingController itemSearchController = TextEditingController();

  List<String> filteredCustomers = [];
  List<Map<String, TextEditingController>> billItems = [];

  @override
  void initState() {
    super.initState();
    loadCustomers();
    loadItems();

    speech = stt.SpeechToText();
    _initSpeech();

    customerSearchController.addListener(filterCustomers);
    itemSearchController.addListener(filterItems);
  }

  Future<void> _initSpeech() async {
    if (_speechAvailable || _speechInitializing) return;
    _speechInitializing = true;
    try {
      _speechAvailable = await speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() => isListening = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => isListening = false);
        },
      );
    } finally {
      _speechInitializing = false;
      if (mounted) setState(() {});
    }
  }

  void startListening() async {
    await _initSpeech();
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech not available / Mic permission denied (check app permissions)',
          ),
        ),
      );
      return;
    }

    if (!isListening) {
      setState(() => isListening = true);

      await speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            itemSearchController.text = result.recognizedWords;
          });
        },
        onSoundLevelChange: (_) {},
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      setState(() => isListening = false);
      await speech.stop();
    }
  }

  Future<void> loadCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('customers')
        .get();

    customers = snapshot.docs.map((doc) => doc['name'].toString()).toList();

    setState(() {});
  }

  Future<void> loadItems() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();

    allItems = snapshot.docs.map((doc) => doc['name'].toString()).toList();

    setState(() {});
  }

  void filterCustomers() {
    final query = customerSearchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredCustomers = [];
      } else {
        filteredCustomers = customers
            .where((customer) => customer.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void filterItems() {
    final query = itemSearchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        filteredItems = [];
      } else {
        filteredItems = allItems
            .where((item) => item.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    speech.stop();
    speech.cancel();
    for (var item in billItems) {
      item['name']?.dispose();
      item['qty']?.dispose();
      item['rate']?.dispose();
    }
    discountController.dispose();
    extraController.dispose();
    customerSearchController.dispose();
    itemSearchController.dispose();
    super.dispose();
  }

  void loadCustomerItems(String customer) {
    for (var item in billItems) {
      item['name']?.dispose();
      item['qty']?.dispose();
      item['rate']?.dispose();
    }
    billItems.clear();
    setState(() {});
  }

  Future<void> loadFrequentItems(String customer) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bills')
        .where('customer', isEqualTo: customer)
        .get();

    Map<String, int> itemFrequency = {};

    for (var doc in snapshot.docs) {
      List items = doc['items'] ?? [];

      for (var item in items) {
        String name = item['name'];

        if (itemFrequency.containsKey(name)) {
          itemFrequency[name] = itemFrequency[name]! + 1;
        } else {
          itemFrequency[name] = 1;
        }
      }
    }

    List<String> sortedItems = itemFrequency.keys.toList()
      ..sort((a, b) => itemFrequency[b]!.compareTo(itemFrequency[a]!));

    List<String> topItems = sortedItems.take(5).toList();

    setState(() {
      filteredItems = [...topItems, ...allItems];
    });
  }

  void addNewItem() {
    billItems.add({
      'name': TextEditingController(),
      'qty': TextEditingController(),
      'rate': TextEditingController(),
    });
    setState(() {});
  }

  Future<void> addItemFromSearch() async {
    final itemName = itemSearchController.text.trim();

    if (itemName.isEmpty) return;

    final existing = await FirebaseFirestore.instance
        .collection('items')
        .where('name', isEqualTo: itemName)
        .get();

    double lastPrice = 0;

    if (existing.docs.isNotEmpty) {
      lastPrice = (existing.docs.first['lastPrice'] ?? 0).toDouble();
    } else {
      await FirebaseFirestore.instance.collection('items').add({
        "name": itemName,
        "lastPrice": 0,
        "updatedAt": DateTime.now().toString(),
      });
      await loadItems();
    }

    billItems.add({
      'name': TextEditingController(text: itemName),
      'qty': TextEditingController(),
      'rate': TextEditingController(
        text: lastPrice == 0 ? '' : lastPrice.toString(),
      ),
    });

    setState(() {
      itemSearchController.clear();
      filteredItems = [];
    });
  }

  void removeItem(int index) {
    billItems[index]['name']?.dispose();
    billItems[index]['qty']?.dispose();
    billItems[index]['rate']?.dispose();
    billItems.removeAt(index);
    setState(() {});
  }

  double getSubtotal() {
    double total = 0;
    for (var item in billItems) {
      final qty = double.tryParse(item['qty']?.text ?? '') ?? 0;
      final rate = double.tryParse(item['rate']?.text ?? '') ?? 0;
      total += qty * rate;
    }
    return total;
  }

  double getFinalTotal() {
    final subtotal = getSubtotal();
    final discount = double.tryParse(discountController.text) ?? 0;
    final extra = double.tryParse(extraController.text) ?? 0;
    return subtotal - discount + extra;
  }

  Widget buildItemCard(int index) {
    final item = billItems[index];
    final qty = double.tryParse(item['qty']?.text ?? '') ?? 0;
    final rate = double.tryParse(item['rate']?.text ?? '') ?? 0;
    final total = qty * rate;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(
              controller: item['name'],
              decoration: const InputDecoration(
                labelText: 'Item Name / सामान का नाम',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item['qty'],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty / मात्रा',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: item['rate'],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rate / रेट',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total / कुल: ₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => removeItem(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addCustomerFromSearch() async {
    final newCustomer = customerSearchController.text.trim();

    if (newCustomer.isEmpty) return;

    final existing = await FirebaseFirestore.instance
        .collection('customers')
        .where('name', isEqualTo: newCustomer)
        .get();

    if (existing.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('customers').add({
        "name": newCustomer,
        "createdAt": DateTime.now().toString(),
      });
    }

    await loadCustomers();

    setState(() {
      selectedCustomer = newCustomer;
      customerSearchController.text = newCustomer;
      filteredCustomers = [];
    });

    loadCustomerItems(newCustomer);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer Added / ग्राहक जुड़ गया')),
    );
  }

  Future<void> saveBill() async {
    if (selectedCustomer == null || selectedCustomer!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select customer first')));
      return;
    }

    List<Map<String, dynamic>> items = [];

    for (var item in billItems) {
      final itemName = item['name']?.text ?? "";
      final rateValue = double.tryParse(item['rate']?.text ?? "") ?? 0;

      items.add({
        "name": itemName,
        "qty": double.tryParse(item['qty']?.text ?? "") ?? 0,
        "rate": rateValue,
      });

      final existingItem = await FirebaseFirestore.instance
          .collection('items')
          .where('name', isEqualTo: itemName)
          .get();

      if (existingItem.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('items')
            .doc(existingItem.docs.first.id)
            .update({
              "lastPrice": rateValue,
              "updatedAt": DateTime.now().toString(),
            });
      }
    }

    try {
      await FirebaseFirestore.instance.collection('bills').add({
        "customer": selectedCustomer,
        "items": items,
        "subtotal": getSubtotal(),
        "discount": double.tryParse(discountController.text) ?? 0,
        "extra": double.tryParse(extraController.text) ?? 0,
        "finalTotal": getFinalTotal(),
        "paymentType": paymentType,
        "date": DateTime.now().toString(),
      });

      if (paymentType == 'Credit') {
        await FirebaseFirestore.instance.collection('ledger').add({
          "customer": selectedCustomer,
          "billAmount": getFinalTotal(),
          "pendingAmount": getFinalTotal(),
          "status": "pending",
          "date": DateTime.now().toString(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bill Saved ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = getSubtotal();
    final finalTotal = getFinalTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill / नया बिल'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: customerSearchController,
              decoration: const InputDecoration(
                labelText: 'Search Customer / ग्राहक खोजें',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),

            if (selectedCustomer != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selected Customer / चुना गया ग्राहक: $selectedCustomer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

            if (customerSearchController.text.isNotEmpty &&
                filteredCustomers.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return ListTile(
                      title: Text(customer),
                      onTap: () {
                        setState(() {
                          selectedCustomer = customer;
                          customerSearchController.text = customer;
                          filteredCustomers = [];
                        });
                        loadCustomerItems(customer);
                        loadFrequentItems(customer);
                      },
                    );
                  },
                ),
              ),

            if (customerSearchController.text.isNotEmpty &&
                filteredCustomers.isEmpty &&
                selectedCustomer != customerSearchController.text.trim())
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: addCustomerFromSearch,
                  child: const Text('Add Customer / ग्राहक जोड़ें'),
                ),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: itemSearchController,
              decoration: InputDecoration(
                labelText: 'Search Item / सामान खोजें',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),

                suffixIcon: IconButton(
                  icon: Icon(isListening ? Icons.mic : Icons.mic_none),
                  onPressed: startListening,
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (itemSearchController.text.isNotEmpty &&
                filteredItems.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      title: Text(item),
                      onTap: () {
                        itemSearchController.text = item;
                        addItemFromSearch();
                      },
                    );
                  },
                ),
              ),

            if (itemSearchController.text.isNotEmpty && filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: addItemFromSearch,
                  child: const Text('Add New Item / नया सामान जोड़ें'),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: addNewItem,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add Empty Item Row / खाली पंक्ति जोड़ें',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Bill Items / बिल का सामान',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (billItems.isEmpty)
              const Text('No items added / अभी कोई सामान नहीं जोड़ा गया'),

            ...List.generate(billItems.length, (index) => buildItemCard(index)),

            const SizedBox(height: 16),

            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount Amount / छूट राशि',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: extraController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Extra Amount / अतिरिक्त राशि',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            const Text(
              'Payment Type / भुगतान प्रकार',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile(
              value: 'Paid',
              groupValue: paymentType,
              title: const Text('Paid / पूरा भुगतान'),
              onChanged: (value) {
                setState(() {
                  paymentType = value.toString();
                });
              },
            ),
            RadioListTile(
              value: 'Credit',
              groupValue: paymentType,
              title: const Text('Credit / उधार'),
              onChanged: (value) {
                setState(() {
                  paymentType = value.toString();
                });
              },
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtotal / उप-योग: ₹${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Final Total / अंतिम कुल: ₹${finalTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payment / भुगतान: $paymentType',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveBill,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Save Bill / बिल सेव करें',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
