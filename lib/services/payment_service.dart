// 인앱결제 — 결정 리포트 평생 패스 4,900원 (비소모성, 1회 결제).
//
// 상품 ID: decision_report_4900 (Play Console에서 직접 등록해야 함.
// 등록 전에는 스토어에서 상품을 찾지 못해 productNotFound가 된다.)
//
// [결정] 2026-11-11 제미나이 심층 검토 반영 — 소모성(건당 결제)에서
// 비소모성(평생 패스)으로 바꿨다. 이유는 3가지다.
//  1. 온디바이스(서버 저장 없음) + 소모성은 복원이 안 된다. 앱을 지우면
//     결제한 리포트가 증발하고 서버에서 복구할 방법이 없어 환불 분쟁이 된다.
//     비소모성은 스토어 자체 구매 복원이 동작한다.
//  2. "추가 결제 없음" 문구가 사실이 된다. 건당 결제였다면 다음 결정을 볼 때
//     또 결제해야 해서 그 문구는 허위 고지 시비가 된다.
//  3. 되물음 루프의 목적이 재구매가 아니라 스토어 리뷰·공유 바이럴이 된다.
// 한 번 결제하면 모든 결정 리포트를 무제한으로 볼 수 있고,
// 가족 보관함도 3명에서 6명으로 확장된다. 구독 없음.

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String reportProductId = 'decision_report_4900';

/// 평생 패스 해금 플래그 (SharedPreferences 키).
const String reportPassUnlockKey = 'report_pass_unlocked_v1';

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

/// 구매 목록에 평생 패스 구매가 있는지 (순수 함수 — 테스트용).
bool hasPassPurchase(List<PurchaseDetails> purchases) {
  return purchases.any(
    (p) =>
        p.productID == reportProductId &&
        (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored),
  );
}

class PaymentService {
  final InAppPurchase _iap;

  PaymentService([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  /// 평생 패스를 샀는지 (기기 내 해금 플래그).
  static Future<bool> isPassUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(reportPassUnlockKey) == true;
  }

  static Future<void> _setPassUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reportPassUnlockKey, true);
  }

  /// 스토어 결제 가능 여부.
  Future<bool> get isAvailable => _iap.isAvailable();

  /// 상품 정보를 불러온다. 스토어에 없으면 null.
  Future<ProductDetails?> loadProduct() async {
    final response = await _iap.queryProductDetails({reportProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  /// 평생 패스를 산 적이 있는지 스토어에서 확인하고, 있으면 해금한다.
  /// 기기 변경·앱 재설치 뒤 복원용이다. 비소모성이라 스토어 복원이 동작한다.
  /// restorePurchases를 부르면 복원된 구매가 purchaseStream으로 온다.
  Future<bool> restorePass() async {
    if (!await isAvailable) return false;
    final completer = Completer<bool>();
    late StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen(
      (purchases) {
        if (hasPassPurchase(purchases) && !completer.isCompleted) {
          completer.complete(true);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    try {
      await _iap.restorePurchases();
      final has = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      if (has) await _setPassUnlocked();
      return has;
    } finally {
      await sub.cancel();
    }
  }

  /// 평생 패스 1건을 결제한다. 결제 흐름이 끝나면 결과를 돌려준다.
  /// 성공하면 해금 플래그를 켠다.
  Future<PaymentResult> buyPass() async {
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
            // 비소모성: completePurchase는 구매 확인(acknowledge)이다.
            // 소비가 아니라서 다시 사지 않아도 되고, 복원도 된다.
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
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        return PaymentResult.error;
      }
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PaymentResult.error,
      );
      if (result == PaymentResult.success) {
        await _setPassUnlocked();
      }
      return result;
    } finally {
      await sub.cancel();
    }
  }
}
