// 인앱결제 — 결정 리포트 일회성 상품 4,900원.
//
// 상품 ID: decision_report_4900 (Play Console에서 직접 등록해야 함.
// 등록 전에는 스토어에서 상품을 찾지 못해 productNotFound가 된다.)
// 일회성 소모품(consumable)으로 판매한다. 구독 없음, 추가 결제 없음.

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

const String reportProductId = 'decision_report_4900';

enum PaymentResult {
  /// 결제 완료 — 리포트를 보여줘도 된다.
  success,

  /// 사용자가 결제를 취소했다.
  cancelled,

  /// 스토어 결제를 쓸 수 없는 기기·환경이다.
  unavailable,

  /// 상품을 스토어에서 찾지 못했다 (Play Console 미등록).
  productNotFound,

  /// 그 외 결제 오류.
  error,
}

/// 구매 상태를 결과로 바꾼다 (순수 함수 — 테스트용).
PaymentResult mapPurchaseStatus(PurchaseDetails details) {
  switch (details.status) {
    case PurchaseStatus.purchased:
    case PurchaseStatus.restored:
      return PaymentResult.success;
    case PurchaseStatus.canceled:
      return PaymentResult.cancelled;
    case PurchaseStatus.pending:
      return PaymentResult.error;
    case PurchaseStatus.error:
      return PaymentResult.error;
  }
}

class PaymentService {
  final InAppPurchase _iap;

  PaymentService([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  /// 스토어 결제 가능 여부.
  Future<bool> get isAvailable => _iap.isAvailable();

  /// 상품 정보를 불러온다. 스토어에 없으면 null.
  Future<ProductDetails?> loadProduct() async {
    final response =
        await _iap.queryProductDetails({reportProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  /// 결정 리포트 1건을 결제한다. 결제 흐름이 끝나면 결과를 돌려준다.
  Future<PaymentResult> buyReport() async {
    if (!await isAvailable) return PaymentResult.unavailable;
    final product = await loadProduct();
    if (product == null) return PaymentResult.productNotFound;

    final completer = Completer<PaymentResult>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != reportProductId) continue;
          final result = mapPurchaseStatus(purchase);
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            // 소모품: 구매 완료 처리(소비)까지 마쳐야 다시 살 수 있다.
            unawaited(_iap.completePurchase(purchase));
          }
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(PaymentResult.error);
        }
      },
    );
    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        return PaymentResult.error;
      }
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PaymentResult.error,
      );
    } finally {
      await sub.cancel();
    }
  }
}
