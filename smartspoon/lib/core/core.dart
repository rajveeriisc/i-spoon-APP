/// Core module barrel export
///
/// This file exports all shared infrastructure components used across features.
/// Import this file to access core utilities, theme, config, and widgets.
library;

// Configuration
export 'config/app_config.dart';

// Models
export 'models/bite.dart';
export 'models/meal.dart';
export 'models/temperature_log.dart';

// Providers
export 'providers/theme_provider.dart';

// Services
export 'services/app_setup_service.dart';
export 'services/database_service.dart';
export 'services/permission_service.dart';
export 'services/sync_service.dart';
export 'services/scheduled_sync_service.dart';

// Theme
export 'theme/app_theme.dart';

// Utilities
export 'utils/validators.dart';

// Widgets
export 'widgets/app_card.dart';
export 'widgets/geometric_background.dart';
export 'widgets/network_avatar.dart';
export 'widgets/premium_header.dart';
export 'widgets/premium_widgets.dart';
