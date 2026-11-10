// 결과 공유 — 이미지 카드(PNG) 캡처·저장·공유.
//
// RepaintBoundary로 감싼 공유용 카드를 PNG로 캡처한다.
// 저장은 gal(갤러리), 공유는 share_plus(시스템 공유 시트 — 카카오톡도
// 공유 대상에 뜬다). 카카오톡 전용 SDK 공유는 카카오 개발자 콘솔에
// 네이티브 앱 등록이 필요해서 플랜 5번의 후속 과제로 둔다.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// [key]가 달린 RepaintBoundary를 PNG 바이트로 캡처한다.
/// 렌더링이 끝나지 않았으면 null을 돌려준다.
Future<Uint8List?> capturePng(GlobalKey key) async {
  final context = key.currentContext;
  if (context == null) return null;
  final boundary =
      context.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

/// PNG 바이트를 갤러리에 저장한다. 저장 성공 시 true.
Future<bool> savePngToGallery(Uint8List bytes, {String name = 'gyeoljeong-saju'}) async {
  final hasAccess = await Gal.hasAccess();
  if (!hasAccess) {
    final granted = await Gal.requestAccess();
    if (!granted) return false;
  }
  await Gal.putImageBytes(bytes, name: name);
  return true;
}

/// PNG 바이트를 시스템 공유 시트로 공유한다 (카카오톡·메시지·메일 등).
Future<void> sharePngBytes(Uint8List bytes, String text) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: 'gyeoljeong-saju.png', mimeType: 'image/png')],
      text: text,
    ),
  );
}

/// 텍스트만 공유한다 (오늘 운세 등).
Future<void> shareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}
