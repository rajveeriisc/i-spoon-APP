import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/home/widgets/home_sections.dart';
import 'package:smartspoon/features/insights/application/insights_controller.dart';
import 'package:smartspoon/features/insights/infrastructure/mock_insights_repository.dart';
import 'package:smartspoon/features/insights/presentation/insights_dashboard.dart';
import 'package:smartspoon/features/profile/index.dart';

class HomeTabView extends StatefulWidget {
  const HomeTabView({super.key, required this.currentTab});

  final ValueNotifier<int> currentTab;

  @override
  State<HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<HomeTabView> {
  late final InsightsController _insightsController;

  @override
  void initState() {
    super.initState();
    _insightsController = InsightsController(MockInsightsRepository())..init();
  }

  @override
  void dispose() {
    _insightsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.currentTab,
      builder: (_, index, __) {
        return IndexedStack(
          index: index,
          children: [
            const HomeSections(),
            ChangeNotifierProvider.value(
              value: _insightsController,
              child: const InsightsDashboard(),
            ),
            const ProfilePage(),
          ],
        );
      },
    );
  }
}
