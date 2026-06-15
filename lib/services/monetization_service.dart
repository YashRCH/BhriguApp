import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/monetization_constants.dart';
import '../constants/firebase_constants.dart';
import '../models/monetization_status.dart';
import 'revenue_cat_service.dart';

class MonetizationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  Future<MonetizationStatus> status() async {
    try {
      final response =
          await _functions.httpsCallable('getMonetizationStatus').call();
      final data = response.data;

      return MonetizationStatus.fromMap(
        data is Map ? Map<String, dynamic>.from(data) : null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Monetization status unavailable: $e');
      }
      return const MonetizationStatus.free();
    }
  }

  Future<bool> restorePurchases() async {
    final customerInfo = await RevenueCatService.instance.restorePurchases();
    return customerInfo != null;
  }

  Future<Offerings?> offerings() async {
    try {
      return await RevenueCatService.instance.getOfferings();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat offerings unavailable: $e');
      }
      return null;
    }
  }

  Future<CustomerInfo?> customerInfo() async {
    try {
      return await RevenueCatService.instance.getCustomerInfo();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat customer info unavailable: $e');
      }
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    final customerInfo =
        await RevenueCatService.instance.purchasePackage(package);
    return customerInfo != null;
  }

  Uri manageSubscriptionUri() {
    return Uri.https(
      'play.google.com',
      '/store/account/subscriptions',
      {
        'sku': bhriguPlusProductId,
        'package': androidPackageName,
      },
    );
  }
}
