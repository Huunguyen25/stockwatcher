import 'package:flutter/material.dart';

class StockListItem extends StatelessWidget {
  final String symbol;
  final String companyName;
  final double price;
  final double priceChange;
  final bool isLoading;
  final VoidCallback? onTap;

  const StockListItem({
    super.key,
    required this.symbol,
    required this.companyName,
    required this.price,
    required this.priceChange,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = priceChange >= 0;
    final Color containerColor = isPositive
        ? const Color(0xFF2ECC71) // Vibrant green
        : const Color(0xFFE74C3C); // Vibrant red-orange

    return InkWell(
      onTap: onTap,
      child: ListTile(
        title: Text(symbol),
        subtitle: Text(companyName),
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Container(
                width: 100, // Fixed width for consistency
                height: 36, // Fixed height for consistency
                alignment: Alignment.center, // Center the text
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}
