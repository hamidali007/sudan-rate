
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

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
      ),
      home: const HomePage(),
    );
  }
}

class CurrencyRate {
  final String name;
  final String code;
  final String flag;
  String buy;
  String sell;

  CurrencyRate({
    required this.name,
    required this.code,
    required this.flag,
    this.buy = '--',
    this.sell = '--',
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<CurrencyRate> currencies = [
    CurrencyRate(
      name: 'الريال السعودي',
      code: 'SAR',
      flag: '🇸🇦',
    ),
    CurrencyRate(
      name: 'الدولار الأمريكي',
      code: 'USD',
      flag: '🇺🇸',
    ),
    CurrencyRate(
      name: 'الجنيه المصري',
      code: 'EGP',
      flag: '🇪🇬',
    ),
  ];

  bool loading = false;
  String? error;
  DateTime? lastFetched;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchRates();

    refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => fetchRates(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchRates() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://ratesudan.com/rates'),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('تعذر الاتصال بالمصدر');
      }

      final document = html_parser.parse(response.body);
      final rows = document.querySelectorAll('tr, [role="row"]');

      final Map<String, List<String>> found = {};

      final numberPattern = RegExp(r'\d[\d,.]*');

      for (final row in rows) {
        final text = row.text.replaceAll('\u00a0', ' ');

        for (final code in ['USD', 'SAR', 'EGP']) {
          if (!RegExp(
            '\\b$code\\b',
            caseSensitive: false,
          ).hasMatch(text)) {
            continue;
          }

          final numbers = numberPattern
              .allMatches(text)
              .map((match) => match.group(0)!)
              .toList();

          // ترتيب الموقع: شراء الموازي، شراء الرسمي،
          // بيع الموازي، بيع الرسمي.
          if (numbers.length >= 4) {
            found[code] = [numbers[0], numbers[2]];
          }
        }
      }

      if (found.length != 3) {
        throw Exception(
          'لم نتمكن من قراءة العملات الثلاث من الموقع',
        );
      }

      if (!mounted) return;

      setState(() {
        for (final currency in currencies) {
          final values = found[currency.code]!;
          currency.buy = values[0];
          currency.sell = values[1];
        }

        lastFetched = DateTime.now();
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'تعذر تحديث الأسعار. تحقق من الإنترنت وحاول مجدداً.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String formatTime(DateTime? date) {
    if (date == null) return 'لم يتم التحديث بعد';

    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

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
          actions: [
            IconButton(
              onPressed: loading ? null : fetchRates,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الأسعار',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: fetchRates,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.currency_exchange,
                        size: 45,
                        color: Colors.green,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'أسعار السوق الموازي السوداني',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text('الأسعار مقابل الجنيه السوداني'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              if (loading)
                const LinearProgressIndicator(),

              if (error != null)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),

              for (final currency in currencies)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              currency.flag,
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currency.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              currency.code,
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 25),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('شراء'),
                                  const SizedBox(height: 6),
                                  Text(
                                    currency.buy,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('بيع'),
                                  const SizedBox(height: 6),
                                  Text(
                                    currency.sell,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'جنيه سوداني',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),
              Center(
                child: Text(
                  'آخر جلب للبيانات: ${formatTime(lastFetched)}',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'المصدر: Rate Sudan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'الأسعار استرشادية وقد تختلف حسب المكتب والوقت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
