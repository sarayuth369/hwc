import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:bkknex_health_app/data/billing/play_billing_service.dart';
import 'package:bkknex_health_app/domain/billing/billing_product.dart';
import 'package:bkknex_health_app/domain/billing/billing_service.dart';

SubscriptionOfferDetailsWrapper _offer({
  required String basePlanId,
  required String price,
  required String token,
  String? offerId,
  int micros = 0,
}) =>
    SubscriptionOfferDetailsWrapper(
      basePlanId: basePlanId,
      offerId: offerId,
      offerTags: const [],
      offerIdToken: token,
      pricingPhases: [
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: basePlanId == 'yearly' ? 'P1Y' : 'P1M',
          formattedPrice: price,
          priceAmountMicros: micros,
          priceCurrencyCode: 'USD',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    );

ProductDetailsWrapper _hwcPremium(List<SubscriptionOfferDetailsWrapper> offers) =>
    ProductDetailsWrapper(
      description: 'HWC Premium',
      name: 'HWC Premium',
      productId: 'hwc_premium',
      productType: ProductType.subs,
      subscriptionOfferDetails: offers,
      title: 'HWC Premium (HWC)',
    );

/// A plugin that blows up as soon as anything touches it (e.g. no Play
/// Billing implementation registered on this device).
class _BrokenIap implements InAppPurchase {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => throw StateError('no billing plugin');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('no billing plugin');
}

class _FakeIap implements InAppPurchase {
  bool available = true;
  ProductDetailsResponse? response;
  Object? throwOnQuery;
  bool buyResult = true;
  PurchaseParam? lastParam;
  final completed = <PurchaseDetails>[];
  int restoreCalls = 0;
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    if (throwOnQuery != null) throw throwOnQuery!;
    return response!;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastParam = purchaseParam;
    return buyResult;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async => restoreCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _details({
  String productId = 'hwc_premium',
  PurchaseStatus status = PurchaseStatus.purchased,
  String token = 'tok',
  bool pendingComplete = false,
  IAPError? error,
}) {
  final d = PurchaseDetails(
    purchaseID: token.isEmpty ? '' : 'GPA.1',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '{}',
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  );
  d.pendingCompletePurchase = pendingComplete;
  d.error = error;
  return d;
}

void main() {
  group('selectBasePlans', () {
    final wrapper = _hwcPremium([
      _offer(basePlanId: 'monthly', price: r'$3.99', token: 'tok-monthly', micros: 3990000),
      _offer(basePlanId: 'yearly', price: r'$44.99', token: 'tok-yearly', micros: 44990000),
    ]);

    test('maps the monthly and yearly base plans with Play-localized prices', () {
      final catalog = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(wrapper),
      );
      expect(catalog.status, BillingCatalogStatus.loaded);

      final monthly = catalog.productFor(BillingPeriod.monthly)!;
      expect(monthly.productId, 'hwc_premium');
      expect(monthly.basePlanId, 'monthly');
      expect(monthly.formattedPrice, r'$3.99');
      expect((monthly.platformHandle as GooglePlayProductDetails).offerToken, 'tok-monthly');

      final yearly = catalog.productFor(BillingPeriod.yearly)!;
      expect(yearly.basePlanId, 'yearly');
      expect(yearly.formattedPrice, r'$44.99');
      expect((yearly.platformHandle as GooglePlayProductDetails).offerToken, 'tok-yearly');
    });

    test('shows whatever localized price Play returns (e.g. a non-USD store)', () {
      final thai = _hwcPremium([
        _offer(basePlanId: 'monthly', price: '฿139.00', token: 'm'),
        _offer(basePlanId: 'yearly', price: '฿1,590.00', token: 'y'),
      ]);
      final catalog = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(thai),
      );
      expect(catalog.productFor(BillingPeriod.monthly)!.formattedPrice, '฿139.00');
      expect(catalog.productFor(BillingPeriod.yearly)!.formattedPrice, '฿1,590.00');
    });

    test('ignores promotional offers and picks the plain base-plan offer', () {
      final withPromo = _hwcPremium([
        _offer(basePlanId: 'monthly', price: r'$0.00', token: 'promo', offerId: 'free-trial'),
        _offer(basePlanId: 'monthly', price: r'$3.99', token: 'base-monthly'),
        _offer(basePlanId: 'yearly', price: r'$44.99', token: 'base-yearly'),
      ]);
      final catalog = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(withPromo),
      );
      final monthly = catalog.productFor(BillingPeriod.monthly)!;
      expect(monthly.formattedPrice, r'$3.99');
      expect((monthly.platformHandle as GooglePlayProductDetails).offerToken, 'base-monthly');
    });

    test('offers only the plans that exist (e.g. yearly missing)', () {
      final onlyMonthly = _hwcPremium([_offer(basePlanId: 'monthly', price: r'$3.99', token: 'm')]);
      final catalog = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(onlyMonthly),
      );
      expect(catalog.productFor(BillingPeriod.monthly), isNotNull);
      expect(catalog.productFor(BillingPeriod.yearly), isNull);
    });

    test('reports productNotFound when none of our base plans are returned', () {
      final other = _hwcPremium([_offer(basePlanId: 'weekly', price: r'$1.00', token: 'w')]);
      final catalog = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(other),
      );
      expect(catalog.status, BillingCatalogStatus.productNotFound);
      expect(catalog.products, isEmpty);
    });
  });

  group('mapPurchase', () {
    test('maps a real purchase, carrying the token and the need to acknowledge', () {
      final mapped = PlayBillingService.mapPurchase(_details(token: 'abc', pendingComplete: true))!;
      expect(mapped.status, BillingPurchaseStatus.purchased);
      expect(mapped.purchaseToken, 'abc');
      expect(mapped.needsCompletion, isTrue);
      expect(mapped.productId, 'hwc_premium');
    });

    test('maps restored and pending', () {
      expect(
        PlayBillingService.mapPurchase(_details(status: PurchaseStatus.restored))!.status,
        BillingPurchaseStatus.restored,
      );
      expect(
        PlayBillingService.mapPurchase(_details(status: PurchaseStatus.pending))!.status,
        BillingPurchaseStatus.pending,
      );
    });

    test('drops the plugin\'s phantom "purchased" entry (no product, no token)', () {
      final phantom = _details(productId: '', token: '', status: PurchaseStatus.purchased);
      expect(PlayBillingService.mapPurchase(phantom), isNull);
    });

    test('attributes a product-less cancel/error to hwc_premium so it is not lost', () {
      final canceled = PlayBillingService.mapPurchase(
        _details(productId: '', token: '', status: PurchaseStatus.canceled),
      )!;
      expect(canceled.status, BillingPurchaseStatus.canceled);
      expect(canceled.productId, 'hwc_premium');
      expect(canceled.purchaseToken, isNull);

      final failed = PlayBillingService.mapPurchase(
        _details(productId: '', token: '', status: PurchaseStatus.error),
      )!;
      expect(failed.status, BillingPurchaseStatus.error);
      expect(failed.productId, 'hwc_premium');
    });

    test('flags an "item already owned" error', () {
      final owned = PlayBillingService.mapPurchase(
        _details(
          productId: '',
          token: '',
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: 'BillingResponse.itemAlreadyOwned',
          ),
        ),
      )!;
      expect(owned.alreadyOwned, isTrue);
    });
  });

  group('a device without a working billing plugin', () {
    test('constructing the service never throws, and everything degrades gracefully', () async {
      final service = PlayBillingService(iap: _BrokenIap());
      expect((await service.loadCatalog()).status, BillingCatalogStatus.billingUnavailable);
      await service.restorePurchases(); // no throw
      await service.completePurchase(
        const BillingPurchase(
          productId: 'hwc_premium',
          status: BillingPurchaseStatus.purchased,
        ),
      );
      const product = BillingProduct(
        productId: 'hwc_premium',
        period: BillingPeriod.monthly,
        basePlanId: 'monthly',
        formattedPrice: r'$3.99',
      );
      expect(await service.purchase(product, accountId: 'u'), PurchaseStart.productUnavailable);
      service.dispose();
    });
  });

  group('service', () {
    late _FakeIap iap;
    late PlayBillingService service;

    setUp(() {
      iap = _FakeIap();
      service = PlayBillingService(iap: iap);
    });

    tearDown(() => service.dispose());

    test('buffers store updates that arrive before anyone listens, then delivers them', () async {
      iap.controller.add([_details(token: 'early')]);
      await Future<void>.delayed(Duration.zero);

      final first = await service.purchases.first;
      expect(first.purchaseToken, 'early');
    });

    test('loadCatalog returns the real offers', () async {
      iap.response = ProductDetailsResponse(
        productDetails: GooglePlayProductDetails.fromProductDetails(_hwcPremium([
          _offer(basePlanId: 'monthly', price: r'$3.99', token: 'm'),
          _offer(basePlanId: 'yearly', price: r'$44.99', token: 'y'),
        ])),
        notFoundIDs: const [],
      );
      final catalog = await service.loadCatalog();
      expect(catalog.status, BillingCatalogStatus.loaded);
      expect(catalog.products, hasLength(2));
    });

    test('loadCatalog degrades gracefully when Play Billing is unavailable', () async {
      iap.available = false;
      final catalog = await service.loadCatalog();
      expect(catalog.status, BillingCatalogStatus.billingUnavailable);
    });

    test('loadCatalog never throws when the store query fails', () async {
      iap.throwOnQuery = StateError('boom');
      final catalog = await service.loadCatalog();
      expect(catalog.status, BillingCatalogStatus.error);
    });

    test('loadCatalog reports a store error response', () async {
      iap.response = ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: const [],
        error: IAPError(source: 'google_play', code: 'x', message: 'y'),
      );
      expect((await service.loadCatalog()).status, BillingCatalogStatus.error);
    });

    test('loadCatalog reports productNotFound when hwc_premium does not exist', () async {
      iap.response = ProductDetailsResponse(productDetails: const [], notFoundIDs: ['hwc_premium']);
      expect((await service.loadCatalog()).status, BillingCatalogStatus.productNotFound);
    });

    test('purchase launches the chosen offer tagged with the account id', () async {
      final details = GooglePlayProductDetails.fromProductDetails(_hwcPremium([
        _offer(basePlanId: 'monthly', price: r'$3.99', token: 'tok-m'),
        _offer(basePlanId: 'yearly', price: r'$44.99', token: 'tok-y'),
      ]));
      final catalog = PlayBillingService.selectBasePlans(details);
      final result = await service.purchase(
        catalog.productFor(BillingPeriod.yearly)!,
        accountId: 'user-42',
      );

      expect(result, PurchaseStart.started);
      final param = iap.lastParam! as GooglePlayPurchaseParam;
      expect(param.offerToken, 'tok-y');
      expect(param.applicationUserName, 'user-42');
      expect(param.productDetails.id, 'hwc_premium');
    });

    test('purchase reports billingUnavailable / productUnavailable / error', () async {
      final product = PlayBillingService.selectBasePlans(
        GooglePlayProductDetails.fromProductDetails(
          _hwcPremium([_offer(basePlanId: 'monthly', price: r'$3.99', token: 'm')]),
        ),
      ).productFor(BillingPeriod.monthly)!;

      iap.available = false;
      expect(await service.purchase(product, accountId: 'u'), PurchaseStart.billingUnavailable);
      iap.available = true;

      iap.buyResult = false;
      expect(await service.purchase(product, accountId: 'u'), PurchaseStart.error);

      const noHandle = BillingProduct(
        productId: 'hwc_premium',
        period: BillingPeriod.monthly,
        basePlanId: 'monthly',
        formattedPrice: r'$3.99',
      );
      expect(await service.purchase(noHandle, accountId: 'u'), PurchaseStart.productUnavailable);
    });

    test('restore re-queries the store, and completePurchase acknowledges via the plugin', () async {
      await service.restorePurchases();
      expect(iap.restoreCalls, 1);

      final mapped = PlayBillingService.mapPurchase(_details(pendingComplete: true))!;
      await service.completePurchase(mapped);
      expect(iap.completed, hasLength(1));
    });

    test('restore is a no-op (not a crash) when Play Billing is unavailable', () async {
      iap.available = false;
      await service.restorePurchases();
      expect(iap.restoreCalls, 0);
    });
  });
}
