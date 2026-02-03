import 'dart:io';

import 'package:flutter/foundation.dart';

// import 'package:aezakmi_price_service/aezakmi_price_service.dart';
// import 'package:aezakmi_price_service/price_service.dart';
// import 'package:apphud/apphud.dart';
// import 'package:video_downloader_328/core/core.dart';

final ValueNotifier<bool> isSubscribed = ValueNotifier(
  Platform.isAndroid ? true : false,
);
final ValueNotifier<bool> hasTrial = ValueNotifier(false);
final ValueNotifier<bool> hasPremium = ValueNotifier(false);

// TODO:

// late PriceProductService weekProduct;
// late PriceProductService weekTrialProduct;

// class PurchaseService {
//   PurchaseService._internal();

//   factory PurchaseService() {
//     return _instance;
//   }

//   static final PurchaseService _instance = PurchaseService._internal();
//   static PurchaseService get instance => _instance;

//   Future init() async {
//     await AezakmiPriceService().initialize(
//       apphudKey: AppConstants.apphudId,
//       apphudPaywallsFallbackPath: "ios/apphud_paywalls_fallback.json",
//       storeKitPath: "ios/Paywall.storekit",
//       paywallID: "paywall",
//       productsID: [
//         AppConstants.weekSubID,
//         AppConstants.weekTrialSubID,
//         AppConstants.lifeTimeSubID,
//       ],
//     );

//     weekProduct = AezakmiPriceService().getProduct(AppConstants.weekSubID);
//     weekTrialProduct = AezakmiPriceService().getProduct(
//       AppConstants.weekTrialSubID,
//     );
//     lifetimeProduct = AezakmiPriceService().getProduct(
//       AppConstants.lifeTimeSubID,
//     );

//     isSubscribed.value =
//         (await Apphud.hasActiveSubscription() ||
//         await Apphud.hasPremiumAccess());
//   }

//   Future purchase({required PriceProductService priceProductService}) async {
//     final result = await Apphud.purchase(
//       product: priceProductService.apphudProduct,
//     );

//     if ((result.subscription?.isActive ?? false) ||
//         (result.nonRenewingPurchase?.isActive ?? false || kDebugMode)) {
//       isSubscribed.value = true;
//     }

//     if (kDebugMode) {
//       hasTrial.value =
//           priceProductService.apphudProduct.productId ==
//           AppConstants.weekTrialSubID;

//       hasPremium.value =
//           priceProductService.apphudProduct.productId ==
//           AppConstants.lifeTimeSubID;
//     } else {
//       hasTrial.value = result.subscription == null
//           ? false
//           : result.subscription!.isActive &&
//                 result.subscription?.productId == AppConstants.weekTrialSubID;

//       hasPremium.value = result.nonRenewingPurchase == null
//           ? false
//           : result.nonRenewingPurchase!.isActive &&
//                 result.nonRenewingPurchase?.productId ==
//                     AppConstants.lifeTimeSubID;
//     }
//   }

//   Future restore() async {
//     final result = await Apphud.restorePurchases();

//     if (result.subscriptions.any((element) => element.isActive) ||
//         result.purchases.any((element) => element.isActive) ||
//         kDebugMode) {
//       isSubscribed.value = true;
//     }

//     hasTrial.value =
//         result.purchases.any(
//           (element) =>
//               element.productId == AppConstants.weekTrialSubID &&
//               element.isActive,
//         ) ||
//         result.subscriptions.any(
//           (element) =>
//               element.productId == AppConstants.weekTrialSubID &&
//               element.isActive,
//         );

//     hasPremium.value =
//         result.purchases.any(
//           (element) =>
//               element.productId == AppConstants.lifeTimeSubID &&
//               element.isActive,
//         ) ||
//         result.subscriptions.any(
//           (element) =>
//               element.productId == AppConstants.lifeTimeSubID &&
//               element.isActive,
//         );
//   }
// }
