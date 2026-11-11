import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/decision_log_screen.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/saju_screen.dart';
import 'services/family_store.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 알림 초기화에 실패해도 앱은 정상 시작한다.
    await followUpNotifications.initialize();
  } catch (_) {
    // 알림 없이 시작한다. 30일 뒤 되물음은 인앱 배너가 대신 알린다.
  }
  try {
    // 구매 스트림 전역 구독 — 결제 완료·복원 구매를 놓치지 않는다.
    PaymentService.initGlobalListener();
  } catch (_) {
    // 구독 실패는 결제 진입 때 다시 시도한다.
  }
  runApp(const DecisionSajuApp());
}

class DecisionSajuApp extends StatelessWidget {
  const DecisionSajuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '결정사주',
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  List<FamilyMember> _members = [];
  int _maxMembers = FamilyStore.maxMembers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMembers() async {
    // 평생 패스를 샀으면 가족 보관함 상한이 3명에서 6명으로 늘어난다.
    // 앱 시작에서는 로컬 해금 플래그만 본다. 스토어 복원을 여기서 기다리면
    // 미구매자는 매번 빈 응답을 기다리느라 시작이 늦어진다.
    var maxMembers = FamilyStore.maxMembers;
    try {
      if (await PaymentService.isPassUnlocked()) {
        maxMembers = FamilyStore.maxMembersUnlocked;
      }
    } catch (_) {
      // 플래그 읽기 실패는 무료 상한으로 시작한다.
    }
    final members = await FamilyStore.load(maxMembers: maxMembers);
    if (!mounted) return;
    setState(() {
      _members = members;
      _maxMembers = maxMembers;
      _loading = false;
    });
    // 백그라운드 복원 — 기기 변경·재설치 뒤면 해금하고 상한을 올린다.
    // 시작을 막지 않는다. 복원되면 보관함을 다시 읽어 6명으로 넓힌다.
    if (maxMembers == FamilyStore.maxMembers) {
      unawaited(
        PaymentService().restorePass().then((restored) async {
          if (!restored || !mounted) return;
          final reloaded = await FamilyStore.load(
            maxMembers: FamilyStore.maxMembersUnlocked,
          );
          if (!mounted) return;
          setState(() {
            _members = reloaded;
            _maxMembers = FamilyStore.maxMembersUnlocked;
          });
        }),
      );
    }
  }

  Future<void> _addMember(FamilyMember member) async {
    final next =
        await FamilyStore.add(_members, member, maxMembers: _maxMembers);
    setState(() => _members = next);
  }

  Future<void> _removeMember(String id) async {
    final next =
        await FamilyStore.remove(_members, id, maxMembers: _maxMembers);
    setState(() => _members = next);
  }

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        members: _members,
        onGoToFamily: () => _goToTab(2),
        onAddMember: _addMember,
      ),
      SajuScreen(members: _members),
      FamilyScreen(
        members: _members,
        maxMembers: _maxMembers,
        onAdd: _addMember,
        onRemove: _removeMember,
      ),
      const DecisionLogScreen(),
    ];
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: '만세력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom_outlined),
            activeIcon: Icon(Icons.family_restroom),
            label: '가족 보관함',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: '결정 일지',
          ),
        ],
      ),
    );
  }
}
