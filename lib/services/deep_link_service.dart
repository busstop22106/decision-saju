// 딥링크 — 작명별과의 양방향 연결.
//
// 들어오는 링크: decision-saju://open?from=naming-star (작명별에서 옴)
//   → 가족 보관함 탭을 먼저 보여준다. 작명별에서 지은 이름의 사주를
//   이어서 보는 흐름이다.
// 나가는 링크: jakmyeongbyeol://open?from=decision-saju (작명별 스킴)
//   → 작명별이 없으면 Play 스토어로 보낸다.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// 작명별 패키지명 (스토어 폴백용).
const String namingStarPackage = 'com.jakmyeongbyeol.app';

/// 들어오는 딥링크가 가리키는 곳.
enum DeepLinkRoute { home, family }

/// 딥링크 URI를 해석한다 (순수 함수 — 테스트용).
///
/// - decision-saju://open?from=naming-star → family
///   (작명별에서 왔으면 가족 보관함을 먼저 보여준다)
/// - decision-saju://open?tab=family → family
/// - 그 외 decision-saju://… → home
/// - 스킴이 다르면 home
DeepLinkRoute parseDeepLink(Uri uri) {
  if (uri.scheme != 'decision-saju') return DeepLinkRoute.home;
  final from = uri.queryParameters['from'];
  final tab = uri.queryParameters['tab'];
  if (from == 'naming-star' || tab == 'family') {
    return DeepLinkRoute.family;
  }
  return DeepLinkRoute.home;
}

/// 앱이 꺼진 상태에서 딥링크로 열린 경우의 첫 링크.
Future<Uri?> getInitialDeepLink() async {
  try {
    return await AppLinks().getInitialLink();
  } catch (_) {
    return null;
  }
}

/// 앱이 켜진 상태에서 들어오는 딥링크 스트림.
Stream<Uri> get deepLinkStream {
  try {
    return AppLinks().uriLinkStream;
  } catch (_) {
    return const Stream.empty();
  }
}

/// 작명별 앱을 연다. 설치되어 있지 않거나 스킴이 없으면 스토어로 보낸다.
/// 무언가를 열었으면 true.
Future<bool> openNamingStar() async {
  final schemeUri =
      Uri.parse('jakmyeongbyeol://open?from=decision-saju');
  try {
    if (await canLaunchUrl(schemeUri)) {
      return await launchUrl(
        schemeUri,
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (_) {
    // 아래 스토어 폴백으로 이어간다.
  }
  final marketUri = Uri.parse('market://details?id=$namingStarPackage');
  try {
    if (await canLaunchUrl(marketUri)) {
      return await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (_) {
    // 아래 웹 스토어로 이어간다.
  }
  final webUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$namingStarPackage',
  );
  try {
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
