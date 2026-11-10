import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/decision_log_screen.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/saju_screen.dart';
import 'services/family_store.dart';
import 'theme/app_theme.dart';

void main() {
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await FamilyStore.load();
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _addMember(FamilyMember member) async {
    final next = await FamilyStore.add(_members, member);
    setState(() => _members = next);
  }

  Future<void> _removeMember(String id) async {
    final next = await FamilyStore.remove(_members, id);
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
