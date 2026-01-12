/// Insights feature barrel export
/// 
/// Import this file to access all insights-related functionality
library;

// Domain layer
export 'domain/domain.dart';
export 'domain/models.dart';
export 'domain/insights_repository.dart';

// Infrastructure layer
export 'infrastructure/live_insights_repository.dart';
export 'infrastructure/mock_insights_repository.dart';

// Application layer
export 'application/insights_controller.dart';

// Presentation layer
export 'presentation/insights_dashboard.dart';
export 'presentation/bite_history_page.dart';
export 'presentation/tremor_history_page.dart';

export 'presentation/screens/heater_control_page.dart';
export 'presentation/screens/meals_analysis_page.dart';

// Widgets
export 'presentation/widgets/daily_food_timeline.dart';
export 'presentation/widgets/environment_device.dart';
export 'presentation/widgets/header.dart';
export 'presentation/widgets/recommendations.dart';
export 'presentation/widgets/summary_cards.dart';
export 'presentation/widgets/temperature_section.dart';
export 'presentation/widgets/tremor_charts.dart';
export 'presentation/widgets/trend_analytics.dart';

// Analytics redesign
export 'presentation/theme/wellness_colors.dart';
export 'presentation/widgets/analytics_widgets.dart';
