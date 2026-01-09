import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/stock_service.dart';
import '../services/holiday_service.dart';

class ApiToolsScreen extends StatefulWidget {
  const ApiToolsScreen({super.key});

  @override
  State<ApiToolsScreen> createState() => _ApiToolsScreenState();
}

class _ApiToolsScreenState extends State<ApiToolsScreen> {
  final TextEditingController _tickerController = TextEditingController(text: 'AAPL');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(text: 'US');
  bool _priceAbove = true;
  String _status = '';
  String _holidayStatus = '';
  bool _loading = false;
  bool _loadingHighlights = false;
  List<StockQuote> _topStocks = [];
  final PageController _highlightsPageController = PageController(viewportFraction: 0.85);
  int _currentHighlightPage = 0;

  @override
  void initState() {
    super.initState();
    _loadStockHighlights();
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _priceController.dispose();
    _countryController.dispose();
    _highlightsPageController.dispose();
    super.dispose();
  }

  Future<void> _loadStockHighlights() async {
    setState(() {
      _loadingHighlights = true;
    });
    try {
      final stocks = await StockService.fetchTopMajors();
      if (mounted) {
        setState(() {
          _topStocks = stocks;
          _loadingHighlights = false;
        });
      }
    } catch (e) {
      print('Error loading stock highlights: $e');
      if (mounted) {
        setState(() {
          _topStocks = [];
          _loadingHighlights = false;
        });
      }
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _status = 'Please sign in to use API tools.';
      });
      return false;
    }
    return true;
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _loading = true;
      _status = 'Fetching quote...';
    });
    try {
      final quote = await StockService.fetchQuote(_tickerController.text.trim());
      setState(() {
        _status =
            '${quote.symbol} → ${quote.current.toStringAsFixed(2)} (open ${quote.open.toStringAsFixed(2)}, high ${quote.high.toStringAsFixed(2)}, low ${quote.low.toStringAsFixed(2)})';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _createPriceAlert() async {
    final target = double.tryParse(_priceController.text.trim());
    if (target == null) {
      setState(() {
        _status = 'Enter a valid target price';
      });
      return;
    }

    if (!await _ensureLoggedIn()) return;

    setState(() {
      _loading = true;
      _status = 'Creating alert...';
    });

    try {
      await StockService.addPriceAlert(
        symbol: _tickerController.text.trim(),
        targetPrice: target,
        direction: _priceAbove ? 'above' : 'below',
      );
      setState(() {
        _status = 'Alert saved. We will notify when ${_priceAbove ? 'above' : 'below'} $target.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _syncHolidays() async {
    if (!await _ensureLoggedIn()) return;

    final countryCode = _countryController.text.trim().toUpperCase();
    if (countryCode.isEmpty) {
      setState(() {
        _holidayStatus = 'Please enter a country code (e.g., US, IN, SG)';
      });
      return;
    }

    setState(() {
      _loading = true;
      _holidayStatus = 'Syncing holidays for $countryCode...';
    });
    try {
      final created = await HolidayService.syncUpcomingHolidays(
        country: countryCode,
        daysAhead: 60,
      );
      setState(() {
        _holidayStatus = 'Synced. $created reminders added for $countryCode.';
      });
    } catch (e) {
      print('Error syncing holidays: $e');
      setState(() {
        _holidayStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: Text(
          'API Tools',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stock Highlights Section
              Text(
                'Stock Highlights',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.voiceCommandStart, AppColors.voiceCommandEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _loadingHighlights
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _topStocks.isEmpty
                        ? Center(
                            child: Text(
                              'No stock data available',
                              style: GoogleFonts.roboto(color: Colors.white),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: _highlightsPageController,
                                  itemCount: _topStocks.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentHighlightPage = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final stock = _topStocks[index];
                                    final change = stock.current - stock.previousClose;
                                    final pct = stock.previousClose == 0
                                        ? 0
                                        : (change / stock.previousClose) * 100;
                                    final isPositive = change >= 0;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  stock.symbol,
                                                  style: GoogleFonts.roboto(
                                                      fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                Text(
                                                  '\$${stock.current.toStringAsFixed(2)}',
                                                  style: GoogleFonts.roboto(
                                                      fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                                ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Icon(
                                                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                                        size: 13,
                                                    ),
                                                      const SizedBox(width: 2),
                                                      Flexible(
                                                        child: Text(
                                                      '${pct.toStringAsFixed(2)}%',
                                                      style: GoogleFonts.roboto(
                                                            fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                                            height: 1.1,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
                                                  style: GoogleFonts.roboto(
                                                      fontSize: 9,
                                                    color: Colors.white.withOpacity(0.8),
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                                ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_topStocks.length, (index) {
                                  return Container(
                                    width: 8.0,
                                    height: 8.0,
                                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentHighlightPage == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 24),
              Divider(color: AppColors.inputBorder),
              const SizedBox(height: 24),
              Text(
                'Stock Market Ticker (Finnhub)',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _tickerController,
                label: 'Ticker (e.g., AAPL)',
                icon: Icons.trending_up,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _priceController,
                label: 'Target price',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _priceAbove,
                    onChanged: (v) => setState(() => _priceAbove = v),
                    activeColor: AppColors.confirmButton,
                  ),
                  Text(
                    _priceAbove ? 'Alert when price is ABOVE target' : 'Alert when price is BELOW target',
                    style: GoogleFonts.roboto(color: AppColors.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () async {
                        await _fetchQuote();
                      },
                      icon: const Icon(Icons.refresh),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.voiceCommandStart,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      label: Text(
                        'Fetch Quote',
                        style: GoogleFonts.roboto(color: AppColors.primaryText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () async {
                        await _createPriceAlert();
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.confirmButton,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      label: Text(
                        'Create Price Alert',
                        style: GoogleFonts.roboto(color: AppColors.primaryText),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: GoogleFonts.roboto(
                  color: _status.startsWith('Error') ? Colors.red : AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: AppColors.inputBorder),
              const SizedBox(height: 24),
              Text(
                'World Public Holidays (Calendarific)',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _countryController,
                label: 'Country Code (e.g., US, IN, SG)',
                icon: Icons.flag_outlined,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () async {
                        await _syncHolidays();
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.voiceCommandEnd,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      label: Text(
                        'Sync Holidays',
                        style: GoogleFonts.roboto(color: AppColors.primaryText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _loading ? null : () async {
                      await _syncHolidays();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _holidayStatus,
                style: GoogleFonts.roboto(
                  color: _holidayStatus.startsWith('Error') ? Colors.red : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        style: GoogleFonts.roboto(color: AppColors.primaryText),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.secondaryText),
          hintText: label,
          hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterText: '', // Hide character counter
        ),
      ),
    );
  }
}

