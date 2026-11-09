// 결정사주 공통 모델
//
// 작명별(~/workspace/naming-star/lib/models.dart)에서 가져온다.
// 동작 변경 없는 이동이다 — 사주 계산에 필요한 것만 옮겼고,
// 이름 짓기 전용 모델(SurnamePick, SharedBaby, DimensionGrade,
// DimensionScore, NameAnalysis)은 가져오지 않았다.
// TODO: GenderX label이 '남아'/'여아'라 성인 가족 구성원에는 맞지 않는다.
// 가족 구성원 입력 화면을 만들 때 남성/여성 표기로 바꿀 것.

enum Gender { boy, girl }

extension GenderX on Gender {
  String get label => this == Gender.boy ? '남아' : '여아';
}

class BabyInfo {
  final String surname;
  final String surnameHanja; // ''이면 미상/직접입력
  final int surnameStrokes;
  final Gender gender;
  final DateTime birth;
  final int? birthHour; // null이면 모름
  final int? birthMinute;

  const BabyInfo({
    required this.surname,
    this.surnameHanja = '',
    required this.surnameStrokes,
    required this.gender,
    required this.birth,
    this.birthHour,
    this.birthMinute,
  });

  bool get timeUnknown => birthHour == null;

  Map<String, dynamic> toJson() => {
        'surname': surname,
        'surnameHanja': surnameHanja,
        'surnameStrokes': surnameStrokes,
        'gender': gender.name,
        'birth': birth.toIso8601String(),
        'birthHour': birthHour,
        'birthMinute': birthMinute,
      };

  factory BabyInfo.fromJson(Map<String, dynamic> j) => BabyInfo(
        surname: j['surname'] as String,
        surnameHanja: j['surnameHanja'] as String? ?? '',
        surnameStrokes: j['surnameStrokes'] as int,
        gender: (j['gender'] as String) == 'boy' ? Gender.boy : Gender.girl,
        birth: DateTime.parse(j['birth'] as String),
        birthHour: j['birthHour'] as int?,
        birthMinute: j['birthMinute'] as int?,
      );

  /// 파싱에 실패한 항목은 null을 돌려준다 — 보관함 불러올 때 그 항목만 건너뛴다.
  /// (fromJson은 엄격 캐스트라 필드 하나만 어긋나도 예외가 나므로 별도로 둔다.)
  static BabyInfo? tryFromJson(Map<String, dynamic> j) {
    try {
      final surname = j['surname'];
      final strokes = j['surnameStrokes'];
      final genderRaw = j['gender'];
      final birthRaw = j['birth'];
      if (surname is! String || surname.isEmpty) return null;
      if (strokes is! num) return null;
      if (genderRaw is! String ||
          (genderRaw != 'boy' && genderRaw != 'girl')) {
        return null;
      }
      if (birthRaw is! String) return null;
      final birth = DateTime.parse(birthRaw);
      final hour = j['birthHour'];
      final minute = j['birthMinute'];
      if (hour is num && (hour < 0 || hour > 23)) return null;
      if (minute is num && (minute < 0 || minute > 59)) return null;
      final hanja = j['surnameHanja'];
      return BabyInfo(
        surname: surname,
        surnameHanja: hanja is String ? hanja : '',
        surnameStrokes: strokes.toInt(),
        gender: genderRaw == 'boy' ? Gender.boy : Gender.girl,
        birth: birth,
        birthHour: hour is num ? hour.toInt() : null,
        birthMinute: minute is num ? minute.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 사주 기둥 하나 (천간 + 지지)
class SajuPillar {
  final String stem; // 갑을병정...
  final String branch; // 자축인묘...
  const SajuPillar(this.stem, this.branch);
  String get label => '$stem$branch';
}

/// 사주 분석 결과 (간이 만세력)
class SajuResult {
  final SajuPillar year;
  final SajuPillar month;
  final SajuPillar day;
  final SajuPillar? hour; // null이면 시간 모름
  final String dayMaster; // 일간
  final String dayElement; // 일간 오행 (목화토금수)
  final Map<String, int> elementCounts; // 오행별 개수 (8자 기준)
  final bool strongBody; // 신강 여부
  final String? yongsin; // 용신 오행
  final String? huishin; // 희신 오행
  final String? johu; // 조후 필요 오행
  final List<String> notes; // 간이 분석 한계 안내

  const SajuResult({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.dayMaster,
    required this.dayElement,
    required this.elementCounts,
    required this.strongBody,
    required this.yongsin,
    required this.huishin,
    required this.johu,
    required this.notes,
  });
}

/// 이름 한 글자에 매칭된 한자
/// (compat.dart의 가족 궁합 중 한자 picks를 받는 메서드가 참조한다.
/// 결정사주에서는 가족 궁합의 사주 부분만 쓰지만,
/// 동작 변경 없는 이동을 위해 모델은 그대로 둔다.)
class HanjaPick {
  final String syllable; // 한글 음절
  final String char; // 한자
  final int strokes; // 원획
  final String element; // 자원오행 (목화토금수)
  final String meaning; // 뜻풀이
  final bool disputed; // 학파별 상이 가능

  const HanjaPick({
    required this.syllable,
    required this.char,
    required this.strokes,
    required this.element,
    required this.meaning,
    this.disputed = false,
  });

  Map<String, dynamic> toJson() => {
        'syllable': syllable,
        'char': char,
        'strokes': strokes,
        'element': element,
        'meaning': meaning,
      };

  factory HanjaPick.fromJson(Map<String, dynamic> j) => HanjaPick(
        syllable: j['syllable'] as String,
        char: j['char'] as String,
        strokes: j['strokes'] as int,
        element: j['element'] as String,
        meaning: j['meaning'] as String,
      );

  /// 파싱에 실패한 항목은 null을 돌려준다 — 보관함 불러올 때 그 항목만 건너뛴다.
  static HanjaPick? tryFromJson(Map<String, dynamic> j) {
    try {
      final syllable = j['syllable'];
      final char = j['char'];
      final strokes = j['strokes'];
      final element = j['element'];
      final meaning = j['meaning'];
      if (syllable is! String || syllable.isEmpty) return null;
      if (char is! String) return null;
      if (strokes is! num) return null;
      if (element is! String) return null;
      if (meaning is! String) return null;
      return HanjaPick(
        syllable: syllable,
        char: char,
        strokes: strokes.toInt(),
        element: element,
        meaning: meaning,
      );
    } catch (_) {
      return null;
    }
  }
}
