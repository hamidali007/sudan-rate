
import 'package:flutter/material.dart';

void main() {
  runApp(const SudanRateApp());
}

class SudanRateApp extends StatelessWidget {
  const SudanRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سعر السودان',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Map<String, String>> currencies = const [
    {'name': 'الريال السعودي', 'code': 'SAR', 'flag': '🇸🇦'},
    {'name': 'الدولار الأمريكي', 'code': 'USD', 'flag': '🇺🇸'},
    {'name': 'الجنيه المصري', 'code': 'EGP', 'flag': '🇪🇬'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سعر السودان',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  children: [
                    Icon(Icons.currency_exchange,
                        size: 45, color: Colors.green),
                    SizedBox(height: 10),
                    Text(
                      'أسعار العملات مقابل الجنيه السوداني',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('السوق الموازي السوداني'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            for (final currency in currencies)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Text(
                    currency['flag']!,
                    style: const TextStyle(fontSize: 30),
                  ),
                  title: Text(
                    currency['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(currency['code']!),
                  trailing: const Text(
                    'بانتظار السعر',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 15),
            const Center(
              child: Text(
                'لم يتم ربط التطبيق بمصدر الأسعار بعد',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
