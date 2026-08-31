// lib/data/models/product_history_model.dart
//
// Traduce entre Firestore y la entidad ProductHistoryEntry. Mismo rol que
// ProductModel para Product.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product_history_entry.dart';

class ProductHistoryModel {
  static ProductHistoryEntry fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return ProductHistoryEntry(
      productId: data['productId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: FoodCategory.fromName(data['category'] as String?),
      entryDate: parseDate(data['entryDate']) ?? DateTime.now(),
      expirationDate: parseDate(data['expirationDate']),
      resolvedAt: parseDate(data['resolvedAt']) ?? DateTime.now(),
      outcome: (data['outcome'] as String?) == 'expired'
          ? ProductOutcome.expired
          : ProductOutcome.consumedOnTime,
      estimatedPrice: (data['estimatedPrice'] as num?)?.toInt(),
    );
  }

  static Map<String, dynamic> toFirestore(ProductHistoryEntry entry) {
    return {
      'productId': entry.productId,
      'name': entry.name,
      'category': entry.category.name,
      'entryDate': entry.entryDate.toIso8601String(),
      if (entry.expirationDate != null)
        'expirationDate': entry.expirationDate!.toIso8601String(),
      'resolvedAt': entry.resolvedAt.toIso8601String(),
      'outcome': entry.outcome.name,
      if (entry.estimatedPrice != null) 'estimatedPrice': entry.estimatedPrice,
    };
  }
}
