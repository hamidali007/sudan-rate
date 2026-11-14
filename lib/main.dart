
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  static const String sourceUrl =
      'https://www.ratesudan.com/rates';

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
        Uri.parse(sourceUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'text/html',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'خطأ في الاتصال بالمصدر: ${response.statusCode}',
        );
      }

      final document = html_parser.parse(response.body);

      final Map<String, List<String>> found = {};

      final numberPattern = RegExp(
        r'\d[\d,.]*',
      );

      // قراءة الجداول وصفوف البيانات من صفحة المصدر.
      final rows = document.querySelectorAll(
        'tr, [role="row"], .row, .rate-row',
      );

      for (final row in rows) {
        final text = row.text
            .replaceAll('\u00a0', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        for (final code in ['USD', 'SAR', 'EGP']) {
          if (!RegExp(
            '\\b$code\\b',
            caseSensitive: false,
          ).hasMatch(text)) {
            continue;
          }

          final numbers = numberPattern
              .allMatches(text)
              .map((m) => m.group(0)!)
              .toList();

          if (numbers.length >= 4) {
            found[code] = [
              numbers[0],
              numbers[2],
            ];
          }
        }
      }

      if (found.length != 3) {
        throw Exception(
          'وصلنا إلى الموقع، لكن لم نستطع قراءة بيانات العملات الثلاث. قد تكون الصفحة محمّلة بطريقة ديناميكية.',
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
    } on TimeoutException {
      if (mounted) {
        setState(() {
          error = 'انتهت مهلة الاتصال بالموقع. حاول مرة أخرى.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
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
    if (date == null) {
      return 'لم يتم التحديث بعد';
    }

    final d = date.toLocal();

    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Widget buildCurrencyCard(CurrencyRate currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  currency.flag,
                  style: const TextStyle(fontSize: 32),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'سعر الشراء',
                        style: TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.buy,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 45,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'سعر البيع',
                        style: TextStyle(color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.sell,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'جنيه سوداني',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
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
                        size: 48,
                        color: Colors.green,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'أسعار العملات في السودان',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('السوق الموازي مقابل الجنيه السوداني'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Center(
                  child: Text('جارٍ جلب الأسعار...'),
                ),
                const SizedBox(height: 12),
              ],

              if (error != null)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: loading ? null : fetchRates,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),

              for (final currency in currencies)
                buildCurrencyCard(currency),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'آخر جلب للبيانات: ${formatTime(lastFetched)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'المصدر: Rate Sudan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
