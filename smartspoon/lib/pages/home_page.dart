import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/main.dart';
import 'package:smartspoon/pages/add_device_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartspoon/features/insights/application/insights_controller.dart';
import 'package:smartspoon/features/insights/infrastructure/mock_insights_repository.dart';
import 'package:smartspoon/features/insights/presentation/insights_dashboard.dart';
import 'package:smartspoon/pages/profile_page.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:smartspoon/features/ble/application/ble_controller.dart';

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
        return ChangeNotifierProvider(
          create: (_) => InsightsController(MockInsightsRepository())..init(),
          child: const InsightsDashboard(),
        );
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
        automaticallyImplyLeading: false, // Remove back arrow
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
              const SpoonConnectedCard(),
              SizedBox(height: padding * 1.5),
              const TemperatureDisplay(),
              SizedBox(height: padding * 1.5),
              const EatingAnalysisCard(),
              SizedBox(height: padding * 1.5),
              Text(
                'Health Insights',
                style: GoogleFonts.lato(
                  fontSize: constraints.maxWidth * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: padding),
              const DailyTipCard(),
              SizedBox(height: padding),
              const MotivationCard(),
              SizedBox(height: padding * 1.5),
              const MyDevices(),
            ],
          ),
        );
      },
    );
  }
}

// SpoonConnectedCard displays the connection status of the smart spoon
class SpoonConnectedCard extends StatelessWidget {
  const SpoonConnectedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.39)
                : Colors.grey.withValues(alpha: 0.20),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconContainer(
            icon: Icons.ramen_dining,
            color: const Color(0xFF00ACC1),
            size: screenWidth * 0.08,
          ),
          SizedBox(width: screenWidth * 0.05),
          _buildSpoonInfo(),
          const Spacer(),
          const Icon(Icons.check_circle, color: Colors.green, size: 30),
        ],
      ),
    );
  }

  // Helper method to build the icon container
  Widget _buildIconContainer({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      padding: EdgeInsets.all(size * 0.3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  // Helper method to build spoon info column
  Widget _buildSpoonInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spoon Connected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00838F),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(
              Icons.battery_charging_full,
              size: 20,
              color: Color(0xFF00838F),
            ),
            SizedBox(width: 8),
            Text(
              '85%',
              style: TextStyle(fontSize: 16, color: Color(0xFF00838F)),
            ),
          ],
        ),
      ],
    );
  }
}

// TemperatureDisplay shows food and heater temperature
class TemperatureDisplay extends StatelessWidget {
  const TemperatureDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.39)
                : Colors.grey.withValues(alpha: 0.12),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Consumer<BleController>(
            builder: (context, controller, _) {
              final t = controller.lastPacket?.temperatureC;
              final formatted = t != null ? '${t.toStringAsFixed(1)}°C' : '--';
              return TemperatureColumn(
                icon: Icons.thermostat,
                label: 'Food Temp',
                temperature: formatted,
                color: const Color(0xFFFFA726),
                fontSize: screenWidth * 0.07,
              );
            },
          ),
          SizedBox(
            height: screenWidth * 0.2,
            child: VerticalDivider(
              color: Colors.grey.withValues(alpha: 0.20),
              thickness: 2,
            ),
          ),
          TemperatureColumn(
            icon: Icons.local_fire_department,
            label: 'Heater Temp',
            temperature: '60°C',
            color: const Color(0xFFEF5350),
            fontSize: screenWidth * 0.07,
          ),
        ],
      ),
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
            color: color.withValues(alpha: 0.12),
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

// EatingAnalysisCard displays daily eating metrics
class EatingAnalysisCard extends StatelessWidget {
  const EatingAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.39)
                : Colors.grey.withValues(alpha: 0.12),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Eating Analysis",
            style: GoogleFonts.lato(
              fontSize: screenWidth * 0.055,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.06),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              InfoColumn(
                icon: Icons.local_dining,
                value: '156',
                unit: 'Total Bites',
                iconColor: Color(0xFF7E57C2),
              ),
              InfoColumn(
                icon: Icons.timer,
                value: '3.2s',
                unit: 'Avg/Bite',
                iconColor: Color(0xFFEC407A),
              ),
              InfoColumn(
                icon: Icons.speed,
                value: 'Medium',
                unit: 'Speed',
                iconColor: Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// DailyTipCard displays a daily health tip
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: screenWidth * 0.1,
            color: const Color(0xFF388E3C),
          ),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: GoogleFonts.lato(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  'Mindful eating can help you recognize true hunger and fullness cues more effectively.',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// MotivationCard displays a motivational quote
class MotivationCard extends StatelessWidget {
  const MotivationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_border,
            size: screenWidth * 0.1,
            color: const Color(0xFFD81B60),
          ),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivation',
                  style: GoogleFonts.lato(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF880E4F),
                  ),
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  '"Slow down, savor life, and nourish your body with intention."',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: const Color(0xFFC2185B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// InfoColumn displays a single metric for eating analysis
class InfoColumn extends StatelessWidget {
  const InfoColumn({
    super.key,
    required this.icon,
    required this.value,
    required this.unit,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String unit;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: screenWidth * 0.1, color: iconColor),
        ),
        SizedBox(height: screenWidth * 0.04),
        Text(
          value,
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          unit,
          style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.04),
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
  List<BluetoothDevice> _connected = const [];
  List<_RecentDevice> _recent = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final connected = FlutterBluePlus.connectedDevices;
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('ble_recent') ?? const <String>[];
      final parsed = list
          .map((s) => _RecentDevice.fromString(s))
          .whereType<_RecentDevice>()
          .toList();
      
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _connected = connected;
          _recent = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final connectedIds = _connected.map((d) => d.remoteId.toString()).toSet();
    final recentNotConnected = _recent
        .where((r) => !connectedIds.contains(r.id))
        .toList();

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

        // Live connected devices
        ..._connected.map(
          (d) => Padding(
            padding: EdgeInsets.only(bottom: screenWidth * 0.04),
            child: DeviceCard(
              deviceName: d.platformName.isNotEmpty
                  ? d.platformName
                  : 'Unknown Device',
              batteryLevel: '—',
              lastUsed: 'Connected now',
              isConnected: true,
            ),
          ),
        ),

        // Previously connected devices
        ...recentNotConnected.map(
          (r) => Padding(
            padding: EdgeInsets.only(bottom: screenWidth * 0.04),
            child: DeviceCard(
              deviceName: r.name,
              batteryLevel: '—',
              lastUsed: 'Previously',
              isConnected: false,
            ),
          ),
        ),

        if (_connected.isEmpty && recentNotConnected.isEmpty)
          Text(
            'No devices yet',
            style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.04),
          ),
      ],
    );
  }
}

class _RecentDevice {
  final String id;
  final String name;
  const _RecentDevice({required this.id, required this.name});
  static _RecentDevice? fromString(String s) {
    final i = s.indexOf('|');
    if (i <= 0) return null;
    final id = s.substring(0, i);
    final name = s.substring(i + 1);
    if (id.isEmpty) return null;
    return _RecentDevice(id: id, name: name.isEmpty ? 'Unknown Device' : name);
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
                    ? Colors.black.withValues(alpha: 0.39)
                    : Colors.grey.withValues(alpha: 0.12),
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
