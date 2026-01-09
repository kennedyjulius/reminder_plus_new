import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/api_keys.dart';
import '../models/reminder_model.dart';
import 'reminder_service.dart';

class StockQuote {
  final String symbol;
  final double current;
  final double open;
  final double high;
  final double low;
  final double previousClose;

  StockQuote({
    required this.symbol,
    required this.current,
    required this.open,
    required this.high,
    required this.low,
    required this.previousClose,
  });

  factory StockQuote.fromJson(String symbol, Map<String, dynamic> json) {
    return StockQuote(
      symbol: symbol.toUpperCase(),
      current: (json['c'] ?? 0).toDouble(),
      open: (json['o'] ?? 0).toDouble(),
      high: (json['h'] ?? 0).toDouble(),
      low: (json['l'] ?? 0).toDouble(),
      previousClose: (json['pc'] ?? 0).toDouble(),
    );
  }
}

class StockAlert {
  final String id;
  final String symbol;
  final double targetPrice;
  final String direction; // 'above' | 'below'
  final bool triggered;

  StockAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.direction,
    required this.triggered,
  });

  Map<String, dynamic> toMap(String userId) {
    return {
      'userId': userId,
      'symbol': symbol,
      'targetPrice': targetPrice,
      'direction': direction,
      'triggered': triggered,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory StockAlert.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockAlert(
      id: doc.id,
      symbol: data['symbol'] ?? '',
      targetPrice: (data['targetPrice'] ?? 0).toDouble(),
      direction: data['direction'] ?? 'above',
      triggered: data['triggered'] ?? false,
    );
  }
}

class StockService {
  static const String _baseUrl = 'https://finnhub.io/api/v1';
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  // Commonly watched large-cap tickers for quick display
  static const List<String> defaultMajors = [
    'AAPL',
    'MSFT',
    'GOOGL',
    'AMZN',
    'TSLA',
  ];

  // Fetch latest quote
  static Future<StockQuote> fetchQuote(String symbol) async {
    try {
      final apiKey = ApiKeys.finnhub;
      if (apiKey.isEmpty || apiKey == 'i9BAKsjbhoLgblLJTNyIzzVi8NSsoJKt') {
        print('⚠️ Warning: Using default/placeholder Finnhub API key. Stock data may not work correctly.');
        print('⚠️ Please set a valid Finnhub API key in lib/constants/api_keys.dart');
      }
      
      final url = Uri.parse('$_baseUrl/quote?symbol=$symbol&token=$apiKey');
      print('📈 Fetching stock quote for $symbol from: $_baseUrl/quote');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout while fetching stock quote for $symbol');
        },
      );

    if (response.statusCode != 200) {
        print('❌ Finnhub API error: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Finnhub request failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Check for API error responses
      if (json.containsKey('error')) {
        print('❌ Finnhub API error: ${json['error']}');
        throw Exception('Finnhub API error: ${json['error']}');
      }
      
      if (json['c'] == null || json['c'] == 0) {
        print('⚠️ Finnhub returned invalid data for $symbol: $json');
        throw Exception('Finnhub returned unexpected data for $symbol');
    }

      final quote = StockQuote.fromJson(symbol, json);
      print('✅ Successfully fetched quote for $symbol: \$${quote.current}');
      return quote;
    } catch (e) {
      print('❌ Error fetching quote for $symbol: $e');
      rethrow;
    }
  }

  // Fetch multiple quotes for a quick "top majors" banner
  static Future<List<StockQuote>> fetchTopMajors({List<String> symbols = defaultMajors}) async {
    final results = <StockQuote>[];

    print('📊 Fetching stock quotes for ${symbols.length} symbols: ${symbols.join(", ")}');

    // Fetch quotes with a small delay between requests to avoid rate limiting
    for (int i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      try {
        // Add a small delay between requests (except for the first one)
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        final quote = await fetchQuote(symbol);
        results.add(quote);
        print('✅ Successfully fetched quote for $symbol: \$${quote.current}');
      } catch (e) {
        // Skip failures so one bad symbol doesn't break the banner
        print('⚠️ Error fetching quote for $symbol: $e');
        print('⚠️ Continuing with other symbols...');
        continue;
      }
    }

    print('📊 Fetched ${results.length} stock quotes out of ${symbols.length} requested');
    
    if (results.isEmpty) {
      print('⚠️ WARNING: No stock quotes were successfully fetched!');
      print('⚠️ This could be due to:');
      print('   1. Invalid or missing Finnhub API key');
      print('   2. Network connectivity issues');
      print('   3. API rate limiting');
      print('   4. Invalid stock symbols');
    }
    
    return results;
  }

  // Add a price alert for the current user
  static Future<String?> addPriceAlert({
    required String symbol,
    required double targetPrice,
    required String direction,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore.collection('stock_alerts').add({
      'userId': user.uid,
      'symbol': symbol.toUpperCase(),
      'targetPrice': targetPrice,
      'direction': direction,
      'triggered': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // Process all pending alerts for the current user
  static Future<void> processAlerts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('stock_alerts')
        .where('userId', isEqualTo: user.uid)
        .where('triggered', isEqualTo: false)
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      final alert = StockAlert.fromDoc(doc);
      try {
        final quote = await fetchQuote(alert.symbol);
        final hitAbove = alert.direction == 'above' && quote.current >= alert.targetPrice;
        final hitBelow = alert.direction == 'below' && quote.current <= alert.targetPrice;

        if (hitAbove || hitBelow) {
          await _firestore.collection('stock_alerts').doc(alert.id).update({
            'triggered': true,
            'triggeredAt': FieldValue.serverTimestamp(),
          });

          final reminder = ReminderModel(
            title: 'Stock ${alert.symbol} ${alert.direction == 'above' ? 'hit' : 'fell below'} ${alert.targetPrice}',
            dateTime: DateTime.now().add(const Duration(minutes: 1)),
            repeat: 'No Repeat',
            snooze: '5 Min',
            createdBy: user.uid,
            source: 'Stock',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {
              'symbol': alert.symbol,
              'current': quote.current,
              'targetPrice': alert.targetPrice,
              'direction': alert.direction,
            },
          );

          await ReminderService.saveReminder(reminder);
        }
      } catch (e) {
        // Continue processing other alerts without failing the entire batch
        // Useful in case of transient network errors or API throttling
        // ignore: avoid_print
        print('Error processing stock alert ${alert.id}: $e');
      }
    }
  }
}

