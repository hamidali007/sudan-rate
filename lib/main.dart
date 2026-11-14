
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oapuddsaszhnmernkowu.supabase.co',
    anonKey: 'sb_publishable_gqxmW0Xk6klDzLobAWmZog_hqMV9Es0',
  );

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
  String buy = '--';
  String sell = '--';

  CurrencyRate({
    required this.name,
    required this.code,
    required this.flag,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

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
  bool showingCache = false;

  @override
  void initState() {
    super.initState();

    loadCache().then((_) => fetchRates());

    refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => fetchRates(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_rates');
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        for (final currency in currencies) {
          final row = data[currency.code] as Map<String, dynamic>?;
          if (row != null) {
            currency.buy = formatRate(row['buy']);
            currency.sell = formatRate(row['sell']);
          }
        }

        lastFetched = DateTime.tryParse(
          data['updated_at']?.toString() ?? '',
        );
        showingCache = true;
      });
    } catch (_) {
      // تجاهل أي خطأ في قراءة النسخة المحفوظة.
    }
  }

  Future<void> saveCache(
    Map<String, Map<String, dynamic>> results,
    DateTime? updated,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = <String, dynamic>{
        for (final c in currencies)
          c.code: {
            'buy': results[c.code]!['buy'],
            'sell': results[c.code]!['sell'],
          },
        'updated_at': updated?.toIso8601String(),
      };

      await prefs.setString('cached_rates', jsonEncode(data));
    } catch (_) {
      // فشل الحفظ لا يجب أن يعطل التطبيق.
    }
  }

  String formatRate(dynamic value) {
    final number = value is num
        ? value
        : num.tryParse(value.toString());

    if (number == null || number <= 0) {
      return '--';
    }

    return number.toString();
  }

  Future<void> fetchRates() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await supabase
          .from('exchange_rates')
          .select('currency, buy, sell, updated_at');

      final Map<String, Map<String, dynamic>> results = {};

      DateTime? latestUpdate;
      bool hasRealRates = false;

      for (final row in response) {
        final code = row['currency'].toString().toUpperCase();

        results[code] = row;

        final buy = num.tryParse(row['buy'].toString()) ?? 0;
        final sell = num.tryParse(row['sell'].toString()) ?? 0;

        if (buy > 0 || sell > 0) {
          hasRealRates = true;
        }

        final date = DateTime.tryParse(
          row['updated_at']?.toString() ?? '',
        );

        if (date != null &&
            (latestUpdate == null ||
                date.isAfter(latestUpdate))) {
          latestUpdate = date;
        }
      }

      for (final currency in currencies) {
        if (!results.containsKey(currency.code)) {
          throw Exception(
            'لم نعثر على بيانات ${currency.code} في قاعدة البيانات.',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        for (final currency in currencies) {
          final row = results[currency.code]!;

          currency.buy = formatRate(row['buy']);
          currency.sell = formatRate(row['sell']);
        }

        lastFetched = hasRealRates ? latestUpdate : null;
        error = null;
        showingCache = false;
      });

      await saveCache(results, latestUpdate);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = showingCache
              ? 'تعذر تحديث الأسعار الآن، '
                  'تُعرض آخر أسعار محفوظة على جهازك.'
              : e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
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
      return 'لم يتم تحديث السعر بعد';
    }

    final d = date.toLocal();

    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Widget currencyCard(CurrencyRate currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(17),
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
                  style: const TextStyle(color: Colors.grey),
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
            const SizedBox(height: 8),
            const Text(
              'جنيه سوداني',
              style: TextStyle(color: Colors.grey),
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
                        color: Colors.green,
                        size: 45,
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
                      Text(
                        'السوق الموازي مقابل الجنيه السوداني',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              if (loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Center(
                  child: Text('جارٍ تحديث الأسعار...'),
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
                          size: 35,
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
                currencyCard(currency),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'آخر تحديث للأسعار: ${formatTime(lastFetched)}',
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
                  'المصدر: لوحة سعر السودان',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'الأسعار استرشادية وقد تختلف حسب المكتب والوقت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
