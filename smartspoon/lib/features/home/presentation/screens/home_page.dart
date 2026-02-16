import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/features/profile/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/features/home/widgets/home_cards.dart'
    as home_widgets;
import 'package:smartspoon/core/theme/app_theme.dart';

// HomePage widget serves as the main entry point for the app's home screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Tracks the currently selected bottom navigation item
  int _selectedIndex = 0;

  // Updates the selected index when a bottom navigation item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Determines which content to display based on the selected index
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomeContent();
      case 1:
        // InsightsController now provided globally in main.dart
        return const InsightsDashboard();
      case 2:
        return const ProfilePage();
      default:
        return const HomeContent();
    }
  }

  // Returns the app bar title based on the selected index
  String _getStaticTitle() {
    const titles = {0: 'Hello', 1: 'Insights', 2: 'My Profile'};
    return titles[_selectedIndex] ?? 'Hello';
  }

  double _appBarTitleFontSize(double width) {
    if (width < 360) return 20;
    if (width < 480) return 24;
    if (width < 720) return 26;
    return 28;
  }

  double _appBarIconSize(double width) {
    if (width < 360) return 22;
    if (width < 480) return 24;
    if (width < 720) return 26;
    return 28;
  }

  EdgeInsets _appBarTitlePadding(double width) {
    final horizontal = width < 360
        ? 12.0
        : width < 720
        ? 16.0
        : 24.0;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  EdgeInsets _appBarActionsPadding(double width) {
    final horizontal = width < 360
        ? 6.0
        : width < 480
        ? 8.0
        : 12.0;
    return EdgeInsets.symmetric(horizontal: horizontal / 2);
  }

  double _appBarToolbarHeight(double width) {
    if (width < 360) return 56;
    if (width < 720) return 64;
    return 72;
  }

  List<Widget> _buildAppBarActions({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required double iconSize,
    required EdgeInsets padding,
  }) {
    return [
      Padding(
        padding: padding,
        child: IconButton(
          icon: Icon(Icons.notifications_none, size: iconSize),
          onPressed: () {},
          tooltip: 'Notifications',
        ),
      ),
      Padding(
        padding: padding,
        child: IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.nightlight_round,
            size: iconSize,
          ),
          onPressed: themeProvider.toggleTheme,
          tooltip: 'Toggle theme',
        ),
      ),
      Padding(
        padding: padding.copyWith(right: padding.horizontal / 2 + 4),
        child: IconButton(
          icon: Icon(Icons.add, size: iconSize),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
            );
          },
          tooltip: 'Add Device',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = _appBarTitleFontSize(screenWidth);
    final iconSize = _appBarIconSize(screenWidth);
    final titlePadding = _appBarTitlePadding(screenWidth);
    final actionsPadding = _appBarActionsPadding(screenWidth);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _appBarToolbarHeight(screenWidth),
        titleSpacing: 0,
        title: Padding(
          padding: titlePadding,
          child: Consumer<UserProvider>(
            builder: (_, user, __) {
              final base = _getStaticTitle();
              final name = (user.name ?? '').trim();
              final firstName = name.isNotEmpty
                  ? (name.contains(' ') ? name.split(RegExp(r'\s+'))[0] : name)
                  : '';
              final title = _selectedIndex == 0
                  ? (firstName.isNotEmpty ? '$base, $firstName' : base)
                  : base;
              return Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        actions: _buildAppBarActions(
          context: context,
          themeProvider: themeProvider,
          iconSize: iconSize,
          padding: actionsPadding,
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

// HomeContent widget displays the main content of the home page
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth * 0.05; // 5% of screen width
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: padding),
              const home_widgets.SpoonConnectedCard(),
              SizedBox(height: padding * 1.5),
              const TemperatureDisplay(),
              SizedBox(height: padding * 1.5),
              const home_widgets.EatingAnalysisCard(),
              SizedBox(height: padding * 1.5),
              Text(
                'Health Insights',
                style: GoogleFonts.lato(
                  fontSize: constraints.maxWidth * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: padding),
              const home_widgets.DailyTipCard(),
              SizedBox(height: padding),
              const home_widgets.MotivationCard(),
              SizedBox(height: padding * 1.5),
              const MyDevices(),
            ],
          ),
        );
      },
    );
  }
}

// TemperatureDisplay shows food and heater temperature (unified with Insights)
class TemperatureDisplay extends StatelessWidget {
  const TemperatureDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Consumer<UnifiedDataService>(
      builder: (context, dataService, _) {
        // foodTempC already reads from McuBleService internally
        final foodTemp = dataService.foodTempC;

        return Container(
          padding: EdgeInsets.all(screenWidth * 0.05),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withAlpha(100)
                    : Colors.grey.withAlpha(30),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HeaterControlPage(),
                      ),
                    );
                  },
                  child: TemperatureColumn(
                    icon: Icons.thermostat,
                    label: 'Food Temp',
                    temperature: '${foodTemp.toStringAsFixed(1)}°C',
                    color: AppTheme.turquoise,
                    fontSize: screenWidth * 0.07,
                  ),
                ),
              ),
              SizedBox(
                height: screenWidth * 0.2,
                child: VerticalDivider(
                  color: AppTheme.sky.withValues(alpha: 0.2),
                  thickness: 2,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HeaterControlPage(),
                      ),
                    );
                  },
                  child: TemperatureColumn(
                    icon: Icons.local_fire_department,
                    label: 'Heater Status',
                    temperature: dataService.isHeaterOn ? 'ON' : 'OFF',
                    color: dataService.isHeaterOn ? AppTheme.gold : Colors.grey,
                    fontSize: screenWidth * 0.07,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// TemperatureColumn displays a single temperature metric
class TemperatureColumn extends StatelessWidget {
  const TemperatureColumn({
    super.key,
    required this.icon,
    required this.label,
    required this.temperature,
    required this.color,
    required this.fontSize,
  });

  final IconData icon;
  final String label;
  final String temperature;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(fontSize * 0.3),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: fontSize * 0.8, color: color),
        ),
        SizedBox(height: fontSize * 0.3),
        Text(
          label,
          style: GoogleFonts.lato(fontSize: fontSize * 0.5, color: Colors.grey),
        ),
        SizedBox(height: fontSize * 0.2),
        Text(
          temperature,
          style: GoogleFonts.lato(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// MyDevices displays a list of connected devices
class MyDevices extends StatefulWidget {
  const MyDevices({super.key});

  @override
  State<MyDevices> createState() => _MyDevicesState();
}

class _MyDevicesState extends State<MyDevices> {
  final _bleService = BleService();

  @override
  void initState() {
    super.initState();
    // Refresh the service's knowledge of saved devices
    _bleService.initialize();

    // Auto-subscribe to MCU data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAutoSubscribe();
    });
  }

  void _setupAutoSubscribe() {
    debugPrint('🚀 Auto-subscribe setup started from MyDevices');
    try {
      final bleService = context.read<BleService>();
      final mcuService = context.read<McuBleService>();

      debugPrint('📱 Services obtained, checking connection status');

      // Try to subscribe immediately if already connected
      _tryAutoSubscribe(bleService, mcuService);

      // Set up periodic retry (every 2 seconds) for up to 10 seconds
      int attempts = 0;
      Timer.periodic(const Duration(seconds: 2), (timer) {
        attempts++;
        if (attempts > 5 || mcuService.isSubscribed) {
          timer.cancel();
          if (mcuService.isSubscribed) {
            debugPrint('✅ Auto-subscribe successful, stopping retries');
          } else {
            debugPrint('⏱️ Auto-subscribe timeout after 10 seconds');
          }
        } else {
          _tryAutoSubscribe(bleService, mcuService);
        }
      });
    } catch (e) {
      debugPrint('❌ Auto-subscribe setup error: $e');
    }
  }

  void _tryAutoSubscribe(BleService bleService, McuBleService mcuService) {
    final connectedIds = bleService.connectedDeviceIds;

    debugPrint(
      '🔍 Auto-subscribe check: connectedIds=${connectedIds.length}, isSubscribed=${mcuService.isSubscribed}',
    );

    if (connectedIds.isEmpty) {
      debugPrint('⚠️ No connected devices');
      return;
    }

    if (mcuService.isSubscribed) {
      debugPrint('✅ Already subscribed, skipping');
      return;
    }

    debugPrint('🔵 Attempting auto-subscribe to MCU data...');
    mcuService
        .subscribeToDevice(connectedIds.first)
        .then((subscribed) {
          if (subscribed) {
            debugPrint('✅ Auto-subscribed to MCU data stream');
          } else {
            debugPrint('⚠️ Auto-subscribe attempt failed, will retry...');
          }
        })
        .catchError((error) {
          debugPrint('❌ Auto-subscribe error: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: _bleService,
      builder: (context, _) {
        final connectedIds = _bleService.connectedDeviceIds;
        final savedDevices = _bleService.previousDevices;

        // Filter out saved devices that are currently connected to avoid duplicates
        final disconnectedSaved = savedDevices
            .where((d) => !connectedIds.contains(d.id))
            .toList();

        final hasDevices =
            connectedIds.isNotEmpty || disconnectedSaved.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Devices',
              style: GoogleFonts.lato(
                fontSize: screenWidth * 0.055,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),

            if (!hasDevices)
              Text(
                'No devices yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: screenWidth * 0.04,
                ),
              ),

            // 1. Live Connected Devices
            ...connectedIds.map((id) {
              // Try to get name from discovered list or saved list
              final device = _bleService.getDeviceById(id);
              String name = device?.name ?? 'Unknown Device';
              if (name.isEmpty) name = 'Unknown Device';

              // If we can't find it in discovered, maybe it's in saved
              if (device == null) {
                final saved = savedDevices.where((d) => d.id == id).firstOrNull;
                if (saved != null) name = saved.name;
              }

              return Padding(
                padding: EdgeInsets.only(bottom: screenWidth * 0.04),
                child: DeviceCard(
                  deviceName: name,
                  batteryLevel:
                      '—', // Use real battery service if available later
                  lastUsed: 'Now',
                  isConnected: true,
                ),
              );
            }),

            // 2. Previously Connected Devices (Disconnected)
            ...disconnectedSaved.map((d) {
              return Padding(
                padding: EdgeInsets.only(bottom: screenWidth * 0.04),
                child: DeviceCard(
                  deviceName: d.name,
                  batteryLevel: '—',
                  lastUsed: d.formattedLastConnected,
                  isConnected: false,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// DeviceCard displays information about a single device
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.batteryLevel,
    required this.lastUsed,
    required this.isConnected,
  });

  final String deviceName;
  final String batteryLevel;
  final String lastUsed;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final maxWidth = constraints.maxWidth;
        final padding = maxWidth * 0.05; // Responsive padding
        final iconSize = maxWidth * 0.08; // Responsive icon size

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withAlpha(100)
                    : Colors.grey.withAlpha(30),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min, // Prevent Row from taking full width
            children: [
              Container(
                padding: EdgeInsets.all(padding * 0.6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.ramen_dining,
                  color: const Color(0xFF673AB7),
                  size: iconSize,
                ),
              ),
              SizedBox(width: padding),
              Expanded(
                // Constrain Column width to prevent overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Minimize vertical space
                  children: [
                    Row(
                      children: [
                        Flexible(
                          // Wrap text to prevent overflow
                          child: Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow:
                                TextOverflow.ellipsis, // Truncate if too long
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        if (isConnected)
                          Row(
                            children: [
                              Icon(
                                Icons.wifi,
                                color: Colors.green,
                                size: screenWidth * 0.05,
                              ),
                              SizedBox(width: padding * 0.25),
                              Icon(
                                Icons.circle,
                                color: Colors.green,
                                size: screenWidth * 0.02,
                              ),
                            ],
                          )
                        else
                          Icon(
                            Icons.wifi_off,
                            color: Colors.grey,
                            size: screenWidth * 0.05,
                          ),
                      ],
                    ),
                    SizedBox(height: padding * 0.5),
                    Row(
                      children: [
                        Icon(
                          Icons.battery_std,
                          size: screenWidth * 0.04,
                          color: Colors.grey,
                        ),
                        SizedBox(width: padding * 0.25),
                        Text(
                          batteryLevel,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Flexible(
                          // Wrap text to prevent overflow
                          child: Text(
                            'Last used $lastUsed',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: screenWidth * 0.035,
                            ),
                            overflow:
                                TextOverflow.ellipsis, // Truncate if too long
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.settings,
                  color: Colors.grey,
                  size: screenWidth * 0.06,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
