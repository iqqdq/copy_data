import 'dart:io';

import 'package:aezakmi_price_service/aezakmi_price_service.dart';
import 'package:aezakmi_price_service/price_service.dart';
import 'package:apphud/apphud.dart';
import 'package:flutter/foundation.dart';

import '../core.dart';

final ValueNotifier<bool> isSubscribed = ValueNotifier(
  Platform.isAndroid ? true : false,
);

late PriceProductService weekProduct;
late PriceProductService weekTrialProduct;

class PurchaseService {
  PurchaseService._internal();

  factory PurchaseService() {
    return _instance;
  }

  static final PurchaseService _instance = PurchaseService._internal();
  static PurchaseService get instance => _instance;

  Future init() async {
    await AezakmiPriceService().initialize(
      apphudKey: AppConstants.apphudId,
      apphudPaywallsFallbackPath: "ios/apphud_paywalls_fallback.json",
      storeKitPath: "ios/Paywall.storekit",
      paywallID: "paywall",
      productsID: [AppConstants.weekSubID, AppConstants.weekTrialSubID],
    );

    weekProduct = AezakmiPriceService().getProduct(AppConstants.weekSubID);
    weekTrialProduct = AezakmiPriceService().getProduct(
      AppConstants.weekTrialSubID,
    );

    isSubscribed.value =
        (await Apphud.hasActiveSubscription() ||
        await Apphud.hasPremiumAccess());
  }

  Future purchase({required PriceProductService priceProductService}) async {
    final result = await Apphud.purchase(
      product: priceProductService.apphudProduct,
    );

    if ((result.subscription?.isActive ?? false) ||
        (result.nonRenewingPurchase?.isActive ?? false || kDebugMode)) {
      isSubscribed.value = true;
    }
  }

  Future restore() async {
    final result = await Apphud.restorePurchases();

    if (result.subscriptions.any((element) => element.isActive) ||
        result.purchases.any((element) => element.isActive) ||
        kDebugMode) {
      isSubscribed.value = true;
    }
  }
}
