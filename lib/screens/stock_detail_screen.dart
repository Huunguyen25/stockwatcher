import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/stock.dart';
import '../models/price_point.dart';
import '../services/api.dart';

enum TimeRange { day, week, month, year, fiveYears, max }

class StockDetailScreen extends StatefulWidget {
  final Stock stock;

  const StockDetailScreen({
    super.key,
    required this.stock,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  TimeRange _selectedRange = TimeRange.day;
  final ApiService _apiService = ApiService();
  YahooChartData? _chartData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoading = true);
    try {
      final range = _getRangeString(_selectedRange);
      final data =
          await _apiService.fetchStockIntraday(widget.stock.symbol, range);
      setState(() => _chartData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getRangeString(TimeRange range) {
    switch (range) {
      case TimeRange.day:
        return '1d';
      case TimeRange.week:
        return '1w'; // Changed from '5d' to '1w'
      case TimeRange.month:
        return '1mo';
      case TimeRange.year:
        return '1y';
      case TimeRange.fiveYears:
        return '5y';
      case TimeRange.max:
        return 'max';
    }
  }

  bool _isPositivePerformance() {
    if (_chartData == null || _chartData!.pricePoints.isEmpty) return false;
    final firstClose = _chartData!.pricePoints.first.price;
    final lastClose = _chartData!.pricePoints.last.price;
    return lastClose > firstClose;
  }

  Color _getPerformanceColor() {
    return _isPositivePerformance() ? Colors.green : Colors.red;
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chartData == null || _chartData!.pricePoints.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final performanceColor = _getPerformanceColor();

    final series = <CartesianSeries>[
      LineSeries<PricePoint, DateTime>(
        dataSource: _chartData!.pricePoints,
        xValueMapper: (PricePoint data, _) => data.timestamp,
        yValueMapper: (PricePoint data, _) => data.price,
        color: performanceColor, // Dynamic color based on performance
      ),
    ];

    // Only add previous close line for 1-day range
    if (_selectedRange == TimeRange.day) {
      series.add(
        LineSeries<PricePoint, DateTime>(
          dataSource: [
            PricePoint(
              _chartData!.pricePoints.first.timestamp,
              _chartData!.previousClose,
            ),
            PricePoint(
              _chartData!.pricePoints.last.timestamp,
              _chartData!.previousClose,
            ),
          ],
          xValueMapper: (PricePoint data, _) => data.timestamp,
          yValueMapper: (PricePoint data, _) => data.price,
          color: Colors.grey,
          dashArray: const [5, 5],
          enableTooltip: false,
        ),
      );
    }

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const DateTimeAxis(
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0),
      ),
      primaryYAxis: const NumericAxis(
        axisLine: AxisLine(width: 0),
        majorTickLines: MajorTickLines(size: 0),
      ),
      series: series,
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: InteractiveTooltip(
          format: 'point.x : \$point.y',
          borderColor: performanceColor, // Dynamic color
          borderWidth: 2,
        ),
        lineType: TrackballLineType.vertical,
        tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }

  Widget _buildRangeButton(TimeRange range) {
    final isSelected = _selectedRange == range;
    final isPositive = isSelected ? _isPositivePerformance() : false;

    String label;
    switch (range) {
      case TimeRange.day:
        label = '1D';
      case TimeRange.week:
        label = '1W';
      case TimeRange.month:
        label = '1M';
      case TimeRange.year:
        label = '1Y';
      case TimeRange.fiveYears:
        label = '5Y';
      case TimeRange.max:
        label = 'MAX';
    }

    return TextButton(
      onPressed: () {
        setState(() => _selectedRange = range);
        _fetchChartData();
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? (isPositive ? Colors.green[100] : Colors.red[100])
            : Colors.transparent,
        foregroundColor: isSelected
            ? (isPositive ? Colors.green : Colors.red)
            : Colors.grey[600],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stock.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Implement menu options
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.stock.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${widget.stock.price?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  widget.stock.priceChange != null &&
                          widget.stock.priceChange! >= 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: widget.stock.priceChange != null &&
                          widget.stock.priceChange! >= 0
                      ? Colors.green
                      : Colors.red,
                ),
                Text(
                  '${widget.stock.priceChange?.abs().toStringAsFixed(2) ?? '0.00'}%',
                  style: TextStyle(
                    fontSize: 18,
                    color: widget.stock.priceChange != null &&
                            widget.stock.priceChange! >= 0
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildChart(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: TimeRange.values
                      .map((range) => _buildRangeButton(range))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
