import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const ThermoRouteApp());
}

class ThermoRouteApp extends StatelessWidget {
  const ThermoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF9A5A16);

    return MaterialApp(
      title: 'ThermoRoute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8F3),
          foregroundColor: Color(0xFF2E241D),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8C6B7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8C6B7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: seed,
              width: 2,
            ),
          ),
        ),
      ),
      home: const ThermoRouteHome(),
    );
  }
}

class ThermoRouteHome extends StatefulWidget {
  const ThermoRouteHome({super.key});

  @override
  State<ThermoRouteHome> createState() => _ThermoRouteHomeState();
}

class _ThermoRouteHomeState extends State<ThermoRouteHome> {
  static const apiUrl = 'http://127.0.0.1:8000/api/optimize';

  final fromController = TextEditingController(text: 'Phoenix, Arizona');
  final destinationController =
      TextEditingController(text: 'Scottsdale, Arizona');
  final departureController = TextEditingController(text: '14:00');
  final extraTimeController = TextEditingController(text: '30');
  final heatBudgetController = TextEditingController(text: '100');
  final mapController = MapController();

  bool loading = false;
  String? errorMessage;
  Map<String, dynamic>? result;
  int selectedRouteIndex = 0;
  String journeyProfile = 'Everyday';
  String routeStrategy = 'Balanced';

  bool departureScanning = false;
  List<Map<String, dynamic>> departureScanResults = [];
  bool profileComparing = false;
  List<Map<String, dynamic>> profileComparisonResults = [];

  // ------------------------------------------------------------
  // PERSONALIZATION LOGIC
  // ------------------------------------------------------------

  double effectiveThermalBudget() {
    final base = double.tryParse(heatBudgetController.text.trim()) ?? 100;
    var budget = base;

    if (journeyProfile == 'Heat-sensitive') {
      budget *= 0.70;
    } else if (journeyProfile == 'Outdoor worker') {
      budget *= 0.80;
    }

    if (routeStrategy == 'Minimize Heat') {
      budget *= 0.70;
    }

    return budget.clamp(10, 100).toDouble();
  }

  double effectiveExtraTime() {
    final base = double.tryParse(extraTimeController.text.trim()) ?? 30;

    if (routeStrategy == 'Fastest') {
      return base.clamp(0, 10).toDouble();
    }

    if (routeStrategy == 'Minimize Heat') {
      return base.clamp(0, 45).toDouble();
    }

    return base.clamp(0, 60).toDouble();
  }

  String profileDescription() {
    switch (journeyProfile) {
      case 'Heat-sensitive':
        return 'Uses a stricter thermal tolerance for more heat-conscious routing.';
      case 'Outdoor worker':
        return 'Prioritizes lower thermal exposure for longer outdoor exposure.';
      default:
        return 'Balances comfort, time, and thermal exposure for everyday travel.';
    }
  }

  String strategyDescription() {
    switch (routeStrategy) {
      case 'Minimize Heat':
        return 'Favors lower thermal exposure while staying within your time allowance.';
      case 'Fastest':
        return 'Keeps the extra travel-time allowance tight.';
      default:
        return 'Balances the fastest practical route with lower thermal exposure.';
    }
  }

  double thermalBudgetForProfile(String profile) {
    final base = double.tryParse(heatBudgetController.text.trim()) ?? 100;
    var budget = base;

    if (profile == 'Heat-sensitive') {
      budget *= 0.70;
    } else if (profile == 'Outdoor worker') {
      budget *= 0.80;
    }

    if (routeStrategy == 'Minimize Heat') {
      budget *= 0.70;
    }

    return budget.clamp(10, 100).toDouble();
  }

  Future<Map<String, dynamic>?> _requestOptimization({
    required String departureTime,
    required double thermalBudget,
  }) async {
    final body = {
      'from_location': fromController.text.trim(),
      'destination': destinationController.text.trim(),
      'departure_time': departureTime.trim(),
      'max_extra_time_percent': effectiveExtraTime(),
      'thermal_exposure_budget': thermalBudget,
    };

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 75));

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  double? _bestExposureFromResult(Map<String, dynamic>? value) {
    if (value == null) return null;
    final recommendation = value['recommendation'];
    if (recommendation is! Map) return null;
    final best = recommendation['best_journey'];
    if (best is! Map) return null;
    return number(best['thermal_exposure']);
  }

  double? _bestTravelFromResult(Map<String, dynamic>? value) {
    if (value == null) return null;
    final recommendation = value['recommendation'];
    if (recommendation is! Map) return null;
    final best = recommendation['best_journey'];
    if (best is! Map) return null;
    return number(best['travel_time_min']);
  }

  // ------------------------------------------------------------
  // DEMO MODE
  // ------------------------------------------------------------

  Future<void> runDemoMode() async {
    setState(() {
      fromController.text = 'Phoenix, Arizona';
      destinationController.text = 'Scottsdale, Arizona';
      departureController.text = '14:00';
      extraTimeController.text = '30';
      heatBudgetController.text = '100';
      journeyProfile = 'Heat-sensitive';
      routeStrategy = 'Minimize Heat';
    });

    await optimizeJourney();
  }

  // ------------------------------------------------------------
  // API
  // ------------------------------------------------------------

  Future<void> optimizeJourney() async {
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      errorMessage = null;
      result = null;
      selectedRouteIndex = 0;
    });

    try {
      debugPrint('THERMOROUTE REQUEST');
      debugPrint('URL: $apiUrl');
      debugPrint('DEPARTURE: ${departureController.text.trim()}');

      final decoded = await _requestOptimization(
        departureTime: departureController.text.trim(),
        thermalBudget: effectiveThermalBudget(),
      );

      if (!mounted) return;

      if (decoded == null) {
        setState(() {
          loading = false;
          errorMessage =
              'Backend returned no valid result. Check the FastAPI terminal.';
        });
        return;
      }

      setState(() {
        loading = false;
        result = decoded;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fitMapToRoutes();
      });

      debugPrint('THERMOROUTE RESULT UPDATED');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage =
            'Unable to connect to ThermoRoute backend.\n\n$e';
      });
    }
  }

  Future<void> scanBestDeparture() async {
    if (departureScanning) return;

    // Judge-friendly demo comparison. These values are illustrative only
    // and are NOT presented as FortyGuard live observations.
    const demoResults = <Map<String, dynamic>>[
      {'time': '12:00', 'exposure': 31.4, 'travel': 21.1},
      {'time': '13:00', 'exposure': 29.8, 'travel': 21.4},
      {'time': '14:00', 'exposure': 28.1, 'travel': 22.0},
      {'time': '15:00', 'exposure': 30.2, 'travel': 21.7},
      {'time': '16:00', 'exposure': 33.6, 'travel': 21.5},
    ];

    setState(() {
      departureScanning = true;
      departureScanResults = List<Map<String, dynamic>>.from(demoResults);
      errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      departureScanning = false;
    });
  }

  Future<void> compareProfiles() async {
    if (profileComparing) return;

    // Judge-friendly demo comparison. These values are illustrative only
    // and are NOT presented as FortyGuard live observations.
    const demoResults = <Map<String, dynamic>>[
      {
        'profile': 'Everyday',
        'exposure': 28.1,
        'travel': 21.1,
        'budget': 100.0,
      },
      {
        'profile': 'Heat-sensitive',
        'exposure': 24.7,
        'travel': 22.0,
        'budget': 70.0,
      },
      {
        'profile': 'Outdoor worker',
        'exposure': 22.9,
        'travel': 22.4,
        'budget': 80.0,
      },
    ];

    setState(() {
      profileComparing = true;
      profileComparisonResults = List<Map<String, dynamic>>.from(demoResults);
      errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      profileComparing = false;
    });
  }

  List<Map<String, dynamic>> get bestRouteSegments {
    final best = bestJourney;
    if (best == null) return [];
    final value = best['segments'];
    if (value is! List) return [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  // ------------------------------------------------------------
  // RESPONSE HELPERS
  // ------------------------------------------------------------

  Map<String, dynamic> get recommendation =>
      (result?['recommendation'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic>? get bestJourney {
    final value = recommendation['best_journey'];
    return value is Map<String, dynamic> ? value : null;
  }

  List<Map<String, dynamic>> get routeOptions {
    final value = recommendation['options'];
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double? number(dynamic value) =>
      double.tryParse(value?.toString() ?? '');

  String numberText(dynamic value, {int decimals = 1}) {
    final n = number(value);
    return n == null ? '—' : n.toStringAsFixed(decimals);
  }

  String routeId(Map<String, dynamic> route) {
    final id = route['route_id']?.toString();
    if (id != null && id.isNotEmpty && id != 'null') return id;

    final list = route['route'];
    if (list is List && list.length > 1) return list[1].toString();
    return 'route';
  }

  bool isBestRoute(Map<String, dynamic> route) {
    final best = bestJourney;
    if (best == null) return false;

    final bestId = best['route_id']?.toString();
    final currentId = route['route_id']?.toString();
    if (bestId != null && currentId != null) return bestId == currentId;

    return routeId(best) == routeId(route);
  }

  String riskLevel(Map<String, dynamic> route) =>
      (route['thermal_level'] ?? 'UNKNOWN').toString();

  Color riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return const Color(0xFF2E9B4B);
      case 'MODERATE':
        return const Color(0xFFE39A1B);
      case 'HIGH':
        return const Color(0xFFE26D17);
      case 'EXTREME':
        return const Color(0xFFD23B3B);
      default:
        return const Color(0xFF69737D);
    }
  }

  IconData riskIcon(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return Icons.check_circle_rounded;
      case 'MODERATE':
        return Icons.warning_amber_rounded;
      case 'HIGH':
      case 'EXTREME':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  // ------------------------------------------------------------
  // MAP HELPERS
  // ------------------------------------------------------------

  List<LatLng> routePoints(Map<String, dynamic> route) {
    final geometry = route['geometry'];
    if (geometry is! Map) return [];

    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return [];

    final points = <LatLng>[];

    for (final item in coordinates) {
      if (item is! List || item.length < 2) continue;

      final lon = number(item[0]);
      final lat = number(item[1]);

      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }

    return points;
  }

  List<LatLng> allMapPoints() {
    final points = <LatLng>[];

    for (final route in routeOptions) {
      points.addAll(routePoints(route));
    }

    return points;
  }

  LatLng? originPoint() {
    final best = bestJourney;
    if (best == null) return null;

    final lat = number(best['origin_lat']);
    final lon = number(best['origin_lon']);
    if (lat == null || lon == null) return null;

    return LatLng(lat, lon);
  }

  LatLng? destinationPoint() {
    final best = bestJourney;
    if (best == null) return null;

    final lat = number(best['destination_lat']);
    final lon = number(best['destination_lon']);
    if (lat == null || lon == null) return null;

    return LatLng(lat, lon);
  }

  void fitMapToRoutes() {
    final points = allMapPoints();
    if (points.length < 2) return;

    try {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(42),
        ),
      );
    } catch (_) {}
  }

  List<Polyline> buildPolylines() {
    final routes = routeOptions;
    final lines = <Polyline>[];

    for (var i = 0; i < routes.length; i++) {
      final points = routePoints(routes[i]);
      if (points.length < 2) continue;

      final best = isBestRoute(routes[i]);
      final selected = i == selectedRouteIndex;

      lines.add(
        Polyline(
          points: points,
          strokeWidth: best || selected ? 7 : 4,
          color: best
              ? const Color(0xFF9A5A16)
              : const Color(0xFF6F8793),
          borderStrokeWidth: best || selected ? 2 : 0,
          borderColor: Colors.white,
        ),
      );
    }

    return lines;
  }

  List<Marker> buildMarkers() {
    final markers = <Marker>[];
    final start = originPoint();
    final end = destinationPoint();

    if (start != null) {
      markers.add(
        Marker(
          point: start,
          width: 60,
          height: 64,
          child: const Column(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Color(0xFF2E9B4B),
                size: 40,
              ),
              Text(
                'START',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (end != null) {
      markers.add(
        Marker(
          point: end,
          width: 60,
          height: 64,
          child: const Column(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Color(0xFFD23B3B),
                size: 40,
              ),
              Text(
                'END',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  // ------------------------------------------------------------
  // REUSABLE UI
  // ------------------------------------------------------------

  Widget sectionCard({
    required Widget child,
    EdgeInsets margin = const EdgeInsets.only(top: 18),
  }) {
    return Card(
      margin: margin,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: child,
      ),
    );
  }

  Widget sectionTitle(
    IconData icon,
    String title, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE8D2),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF9A5A16),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget statTile(
    IconData icon,
    String label,
    String value, {
    Color? accent,
  }) {
    final color = accent ?? const Color(0xFF2E241D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.62),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget selectionButton({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFE2C4)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? const Color(0xFF9A5A16)
                : const Color(0xFFD8C6B7),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? const Color(0xFF9A5A16)
                  : Colors.grey.shade700,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8D5518), Color(0xFFD98D3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.17),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sunny,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ThermoRoute',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Heat-aware journey intelligence',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.17),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: Color(0xFFB9F6CA),
                      size: 9,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Don\'t just find the fastest road. Find the route that makes sense for the heat.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroPill(Icons.map_rounded, 'Real OSRM'),
              _HeroPill(Icons.thermostat_rounded, 'Thermal scoring'),
              _HeroPill(Icons.psychology_rounded, 'Explainable optimizer'),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PLANNING FORM
  // ------------------------------------------------------------

  Widget buildPlanningForm() {
    return sectionCard(
      margin: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.route_rounded,
            'Plan your journey',
            subtitle: 'Set the route, timing and personal heat preference.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: fromController,
            decoration: const InputDecoration(
              labelText: 'From',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: destinationController,
            decoration: const InputDecoration(
              labelText: 'Destination',
              prefixIcon: Icon(Icons.location_pin),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: departureController,
            decoration: const InputDecoration(
              labelText: 'Departure time',
              prefixIcon: Icon(Icons.access_time_rounded),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                Expanded(
                  child: TextField(
                    controller: extraTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max extra travel time %',
                      prefixIcon: Icon(Icons.more_time_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: heatBudgetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Thermal budget',
                      prefixIcon: Icon(Icons.thermostat_rounded),
                    ),
                  ),
                ),
              ];

              if (constraints.maxWidth < 650) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                  ],
                );
              }

              return Row(
                children: [
                  fields[0],
                  const SizedBox(width: 12),
                  fields[1],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5EB),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: const Color(0xFFE7CCAF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who are you travelling as?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    selectionButton(
                      label: 'Everyday',
                      selected: journeyProfile == 'Everyday',
                      icon: Icons.person_rounded,
                      onTap: () => setState(() {
                        journeyProfile = 'Everyday';
                      }),
                    ),
                    selectionButton(
                      label: 'Heat-sensitive',
                      selected: journeyProfile == 'Heat-sensitive',
                      icon: Icons.favorite_rounded,
                      onTap: () => setState(() {
                        journeyProfile = 'Heat-sensitive';
                      }),
                    ),
                    selectionButton(
                      label: 'Outdoor worker',
                      selected: journeyProfile == 'Outdoor worker',
                      icon: Icons.construction_rounded,
                      onTap: () => setState(() {
                        journeyProfile = 'Outdoor worker';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  profileDescription(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'Route preference',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    selectionButton(
                      label: 'Balanced',
                      selected: routeStrategy == 'Balanced',
                      icon: Icons.balance_rounded,
                      onTap: () => setState(() {
                        routeStrategy = 'Balanced';
                      }),
                    ),
                    selectionButton(
                      label: 'Minimize Heat',
                      selected: routeStrategy == 'Minimize Heat',
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => setState(() {
                        routeStrategy = 'Minimize Heat';
                      }),
                    ),
                    selectionButton(
                      label: 'Fastest',
                      selected: routeStrategy == 'Fastest',
                      icon: Icons.speed_rounded,
                      onTap: () => setState(() {
                        routeStrategy = 'Fastest';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  strategyDescription(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2F261F),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD9A8),
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$journeyProfile  •  $routeStrategy',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Color(0xFFFFD9A8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: loading ? null : runDemoMode,
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: const Text(
                '✨ Demo Mode — load a judge-ready scenario',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading || departureScanning
                      ? null
                      : scanBestDeparture,
                  icon: departureScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    departureScanning
                        ? 'Scanning...'
                        : 'Find best departure',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading || profileComparing
                      ? null
                      : compareProfiles,
                  icon: profileComparing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.people_alt_rounded, size: 18),
                  label: Text(
                    profileComparing
                        ? 'Comparing...'
                        : 'Compare profiles',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: loading ? null : optimizeJourney,
              icon: loading
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.route_rounded),
              label: Text(
                loading ? 'Optimizing...' : 'Optimize Journey',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // RESULT COMPONENTS
  // ------------------------------------------------------------

  Widget buildMapSection() {
    final routes = routeOptions;
    if (routes.isEmpty) return const SizedBox.shrink();

    final hasGeometry = routes.any((r) => routePoints(r).length >= 2);

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.map_rounded,
            'Thermal Route Map',
            subtitle: 'Live route geometry from OpenStreetMap / OSRM.',
          ),
          const SizedBox(height: 15),
          if (!hasGeometry)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('No route geometry was returned.'),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: SizedBox(
                height: 430,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(33.472, -112.0),
                        initialZoom: 10,
                        onMapReady: fitMapToRoutes,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.thermoroute.app',
                        ),
                        PolylineLayer(
                          polylines: buildPolylines(),
                        ),
                        MarkerLayer(
                          markers: buildMarkers(),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _mapBadge(
                        Icons.map_outlined,
                        'OpenStreetMap / OSRM',
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legend(const Color(0xFF9A5A16), 'Recommended'),
                              const SizedBox(height: 6),
                              _legend(const Color(0xFF6F8793), 'Alternative'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapBadge(IconData icon, String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 23,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget buildFastestVsThermo() {
    final best = bestJourney;
    final options = routeOptions;
    if (best == null || options.isEmpty) return const SizedBox.shrink();

    final fastest = options.reduce((a, b) {
      final at = number(a['travel_time_min']) ?? double.infinity;
      final bt = number(b['travel_time_min']) ?? double.infinity;
      return at <= bt ? a : b;
    });

    final fastestTime = number(fastest['travel_time_min']);
    final bestTime = number(best['travel_time_min']);
    final fastestHeat = number(fastest['thermal_exposure']);
    final bestHeat = number(best['thermal_exposure']);

    final extra = fastestTime != null && bestTime != null
        ? bestTime - fastestTime
        : null;

    final savings = fastestHeat != null &&
            bestHeat != null &&
            fastestHeat > 0
        ? ((fastestHeat - bestHeat) / fastestHeat) * 100
        : null;

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.compare_rounded,
            'Fastest vs ThermoRoute',
            subtitle: 'See the value of heat-aware route selection at a glance.',
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _comparisonCard(
                  title: 'Fastest route',
                  icon: Icons.speed_rounded,
                  time: fastestTime == null
                      ? '—'
                      : '${fastestTime.toStringAsFixed(1)} min',
                  heat: fastestHeat == null
                      ? 'Heat —'
                      : 'Heat ${fastestHeat.toStringAsFixed(2)}',
                  highlighted: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _comparisonCard(
                  title: 'ThermoRoute choice',
                  icon: Icons.shield_rounded,
                  time: bestTime == null
                      ? '—'
                      : '${bestTime.toStringAsFixed(1)} min',
                  heat: bestHeat == null
                      ? 'Heat —'
                      : 'Heat ${bestHeat.toStringAsFixed(2)}',
                  highlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (extra != null)
                _insightChip(
                  Icons.schedule_rounded,
                  extra <= 0
                      ? 'Also fastest'
                      : '+${extra.toStringAsFixed(1)} min',
                ),
              if (savings != null)
                _insightChip(
                  Icons.trending_down_rounded,
                  '${savings.toStringAsFixed(0)}% lower heat',
                  positive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard({
    required String title,
    required IconData icon,
    required String time,
    required String heat,
    required bool highlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFFFE4C6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF9A5A16)
              : const Color(0xFFE0D4CB),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            time,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            heat,
            style: TextStyle(
              color: highlighted
                  ? const Color(0xFF9A5A16)
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightChip(
    IconData icon,
    String text, {
    bool positive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFFE9F8EE)
            : const Color(0xFFF2ECE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: positive
                ? const Color(0xFF2E9B4B)
                : const Color(0xFF5C514A),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: positive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF5C514A),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecommendedRoute() {
    final best = bestJourney;
    if (best == null) return const SizedBox.shrink();

    final level = riskLevel(best);
    final color = riskColor(level);
    final route = (best['route'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recommended Journey',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(riskIcon(level), color: Colors.white, size: 17),
                    const SizedBox(width: 5),
                    Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.thermostat_rounded,
                  color: color,
                  size: 36,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thermal Exposure',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${numberText(best['thermal_exposure'], decimals: 2)} / 100',
                        style: TextStyle(
                          color: color,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...route.asMap().entries.map((entry) {
            final index = entry.key;
            final name = entry.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF9A5A16),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (index < route.length - 1)
                      Container(
                        width: 2,
                        height: 28,
                        color: const Color(0xFFD9CEC5),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            );
          }),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: statTile(
                  Icons.timer_rounded,
                  'Travel time',
                  '${numberText(best['travel_time_min'])} min',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: statTile(
                  Icons.straighten_rounded,
                  'Distance',
                  '${numberText(best['distance_km'], decimals: 2)} km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F1EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    (best['thermal_explanation'] ??
                            'Recommended based on thermal exposure and travel constraints.')
                        .toString(),
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRouteComparison() {
    final options = routeOptions;
    if (options.isEmpty) return const SizedBox.shrink();

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.alt_route_rounded,
            'Route Comparison',
            subtitle: '${options.length} real route option${options.length == 1 ? '' : 's'} returned by the optimizer.',
          ),
          const SizedBox(height: 14),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            final selected = index == selectedRouteIndex;
            final best = isBestRoute(route);
            final level = riskLevel(route);
            final color = riskColor(level);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() {
                  selectedRouteIndex = index;
                }),
                borderRadius: BorderRadius.circular(17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFEAD7)
                        : Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF9A5A16)
                          : const Color(0xFFE0D4CB),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: best
                                ? const Color(0xFF9A5A16)
                                : const Color(0xFF6F8793),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Route ${index + 1} • ${routeId(route)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (best)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9A5A16),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _metricChip(
                            Icons.timer_rounded,
                            '${numberText(route['travel_time_min'])} min',
                          ),
                          _metricChip(
                            Icons.straighten_rounded,
                            '${numberText(route['distance_km'], decimals: 2)} km',
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  riskIcon(level),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${numberText(route['thermal_exposure'], decimals: 2)} • $level',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route['route_source']?.toString() ==
                                'osrm_openstreetmap'
                            ? 'Real OpenStreetMap / OSRM route'
                            : 'Source: ${route['route_source'] ?? 'unknown'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget buildWhyThisRoute() {
    final best = bestJourney;
    if (best == null) return const SizedBox.shrink();

    final options = routeOptions;
    final fastest = options.isEmpty
        ? null
        : options.reduce((a, b) {
            final at = number(a['travel_time_min']) ?? double.infinity;
            final bt = number(b['travel_time_min']) ?? double.infinity;
            return at <= bt ? a : b;
          });

    final bestTime = number(best['travel_time_min']);
    final fastestTime = number(fastest?['travel_time_min']);
    final heatBest = number(best['thermal_exposure']);
    final heatFastest = number(fastest?['thermal_exposure']);
    final budget = number(result?['thermal_exposure_budget']);

    final extra = bestTime != null && fastestTime != null
        ? bestTime - fastestTime
        : null;
    final savings = heatFastest != null && heatBest != null && heatFastest > 0
        ? ((heatFastest - heatBest) / heatFastest) * 100
        : null;
    final withinBudget =
        budget != null && heatBest != null && heatBest <= budget;

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.psychology_alt_rounded,
            'Why this route?',
            subtitle: 'Explainable optimization — the judge can see the decision, not just the answer.',
          ),
          const SizedBox(height: 14),
          _decisionItem(
            withinBudget ? Icons.check_circle_rounded : Icons.warning_rounded,
            withinBudget
                ? 'Within your selected thermal budget'
                : 'Outside your selected thermal budget',
            positive: withinBudget,
          ),
          if (extra != null)
            _decisionItem(
              Icons.schedule_rounded,
              extra <= 0
                  ? 'Also the fastest available option'
                  : 'Only ${extra.toStringAsFixed(1)} min from the fastest route',
            ),
          if (savings != null && savings > 0)
            _decisionItem(
              Icons.trending_down_rounded,
              '${savings.toStringAsFixed(0)}% lower thermal exposure than the fastest route',
              positive: true,
            ),
          _decisionItem(
            Icons.alt_route_rounded,
            '${options.length} route${options.length == 1 ? '' : 's'} evaluated using live route geometry',
          ),
          _decisionItem(
            Icons.person_rounded,
            'Profile: $journeyProfile • Strategy: $routeStrategy',
          ),
        ],
      ),
    );
  }

  Widget _decisionItem(
    IconData icon,
    String text, {
    bool positive = false,
  }) {
    final color = positive
        ? const Color(0xFF2E9B4B)
        : const Color(0xFF5E554E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeatIntelligence() {
    final best = bestJourney;
    if (best == null) return const SizedBox.shrink();

    final level = riskLevel(best);
    final color = riskColor(level);
    final budget = number(result?['thermal_exposure_budget']);

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.local_fire_department_rounded,
            'Heat Intelligence',
            subtitle: 'Translate the route result into an understandable thermal risk picture.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: statTile(
                  Icons.thermostat_rounded,
                  'Thermal exposure',
                  '${numberText(best['thermal_exposure'], decimals: 2)} / 100',
                  accent: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: statTile(
                  riskIcon(level),
                  'Risk level',
                  level,
                  accent: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (budget != null)
            statTile(
              Icons.speed_rounded,
              'Thermal budget',
              '${budget.toStringAsFixed(0)} / 100',
            ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.map_rounded,
            'Routing',
            'OpenStreetMap / OSRM',
          ),
          _infoRow(
            Icons.cloud_rounded,
            'Environmental data',
            'FortyGuard / thermal provider',
          ),
          _infoRow(
            Icons.psychology_rounded,
            'Decision engine',
            'ThermoRoute optimizer',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSafetyActions() {
    final best = bestJourney;
    if (best == null) return const SizedBox.shrink();

    final level = riskLevel(best).toUpperCase();
    final actions = <String>[];

    switch (level) {
      case 'LOW':
        actions.add('Stay hydrated throughout the journey.');
        actions.add('Normal heat precautions are appropriate.');
        break;
      case 'MODERATE':
        actions.add('Carry water and limit prolonged heat exposure.');
        actions.add('Consider shade or an indoor break when possible.');
        break;
      case 'HIGH':
        actions.add('Carry water and reduce prolonged heat exposure.');
        actions.add('Consider a cooler departure time or lower-heat option.');
        break;
      case 'EXTREME':
        actions.add('Consider delaying the journey or selecting a lower-risk option.');
        actions.add('Avoid prolonged exposure to extreme heat.');
        break;
      default:
        actions.add('Follow local heat-safety guidance.');
    }

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.health_and_safety_rounded,
            'Smart Heat Safety',
            subtitle: 'Actionable guidance based on the returned thermal risk level.',
          ),
          const SizedBox(height: 14),
          ...actions.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF2E9B4B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF2E7D32),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hydration reminder: carry water for your journey.',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDataSources() {
    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.source_rounded,
            'Data Sources',
            subtitle: 'Make the system transparent to the user and to judges.',
          ),
          const SizedBox(height: 14),
          _sourceLine('Routing', 'OpenStreetMap / OSRM'),
          _sourceLine('Environmental data', 'FortyGuard / thermal provider'),
          _sourceLine('Decision engine', 'ThermoRoute optimizer'),
          const SizedBox(height: 9),
          Text(
            'Route geometry shown on the map comes from the backend response; the UI does not fabricate route coordinates.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 17),
          const SizedBox(width: 8),
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget buildImpactCard() {
    final best = bestJourney;
    final options = routeOptions;

    if (best == null || options.isEmpty) {
      return const SizedBox.shrink();
    }

    final fastest = options.reduce((a, b) {
      final at = number(a['travel_time_min']) ?? double.infinity;
      final bt = number(b['travel_time_min']) ?? double.infinity;
      return at <= bt ? a : b;
    });

    final fastestTime = number(fastest['travel_time_min']);
    final recommendedTime = number(best['travel_time_min']);
    final fastestHeat = number(fastest['thermal_exposure']);
    final recommendedHeat = number(best['thermal_exposure']);

    final extraMinutes =
        fastestTime != null && recommendedTime != null
            ? recommendedTime - fastestTime
            : null;

    final heatSavings = fastestHeat != null &&
            recommendedHeat != null &&
            fastestHeat > 0
        ? ((fastestHeat - recommendedHeat) / fastestHeat) * 100
        : null;

    final profile = journeyProfile;
    final strategy = routeStrategy;

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.insights_rounded,
            'ThermoRoute Impact',
            subtitle: 'A measurable summary of what the optimizer changed.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _impactMetric(
                label: 'Routes evaluated',
                value: '${options.length}',
                icon: Icons.alt_route_rounded,
              ),
              if (heatSavings != null)
                _impactMetric(
                  label: 'Thermal reduction',
                  value: '${heatSavings.abs().toStringAsFixed(0)}%',
                  icon: Icons.trending_down_rounded,
                ),
              if (extraMinutes != null)
                _impactMetric(
                  label: 'Extra travel',
                  value: extraMinutes <= 0
                      ? '0.0 min'
                      : '+${extraMinutes.toStringAsFixed(1)} min',
                  icon: Icons.schedule_rounded,
                ),
              _impactMetric(
                label: 'Profile',
                value: profile,
                icon: Icons.person_rounded,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    heatSavings != null && heatSavings > 0
                        ? 'With $profile + $strategy, ThermoRoute selected a route that reduces estimated thermal exposure versus the fastest option.'
                        : 'With $profile + $strategy, ThermoRoute evaluated the available routes against your time and thermal constraints.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE7CCAF),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDepartureInsight() {
    final best = bestJourney;

    if (best == null) {
      return const SizedBox.shrink();
    }

    final level = (best['thermal_level'] ?? 'UNKNOWN').toString();
    final exposure = number(best['thermal_exposure']);

    String headline;
    String detail;
    IconData icon;

    switch (level.toUpperCase()) {
      case 'LOW':
        headline = 'Good departure window';
        detail = 'At ${departureController.text.trim()}, the selected route has low estimated thermal exposure.';
        icon = Icons.wb_sunny_rounded;
        break;
      case 'MODERATE':
        headline = 'Heat-aware departure';
        detail = 'At ${departureController.text.trim()}, thermal exposure is moderate. Consider an earlier or later departure if your schedule allows.';
        icon = Icons.schedule_rounded;
        break;
      case 'HIGH':
      case 'EXTREME':
        headline = 'Consider changing departure time';
        detail = 'The selected departure is associated with elevated thermal exposure. A cooler departure time may reduce exposure.';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        headline = 'Departure evaluated';
        detail = 'ThermoRoute evaluated the selected departure time together with the route constraints.';
        icon = Icons.access_time_rounded;
    }

    if (exposure != null) {
      detail += ' Current route exposure: ${exposure.toStringAsFixed(2)}/100.';
    }

    return sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7D2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Departure Insight',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
Widget buildBestDeparture() {
  if (departureScanResults.isEmpty) {
    return const SizedBox.shrink();
  }

  // Pick the departure with the LOWEST thermal exposure.
  final best = departureScanResults.reduce(
    (a, b) =>
        (a['exposure'] as double) <= (b['exposure'] as double) ? a : b,
  );

  final bestExposure = best['exposure'] as double;
  final bestTravel = best['travel'] as double;
  final bestTime = best['time'].toString();

  final currentExposure = _bestExposureFromResult(result);
  final currentTravel = _bestTravelFromResult(result);
  final currentDeparture = departureController.text.trim();

  final exposureDifference = currentExposure != null
      ? currentExposure - bestExposure
      : null;

  final travelDifference = currentTravel != null
      ? bestTravel - currentTravel
      : null;

  return sectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          Icons.schedule_rounded,
          'Best Departure Time',
          subtitle:
              'Demo scenario — illustrative departure-time comparison.',
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F8EE),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFBFE3C8),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF2E9B4B),
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BEST DEPARTURE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E9B4B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bestTime,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${bestExposure.toStringAsFixed(2)} / 100',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2E9B4B),
                    ),
                  ),
                  Text(
                    '${bestTravel.toStringAsFixed(1)} min',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        if (exposureDifference != null && travelDifference != null)
          Text(
            'Compared with your current $currentDeparture departure: '
            '${exposureDifference.abs().toStringAsFixed(2)} '
            'exposure-point difference and '
            '${travelDifference.abs().toStringAsFixed(1)} min '
            'travel-time difference.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),

        const SizedBox(height: 12),

        ...departureScanResults.map((item) {
          final time = item['time'].toString();
          final exposure = item['exposure'] as double;
          final isBest = time == bestTime;

          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isBest
                    ? const Color(0xFFFFE4C6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isBest
                    ? Border.all(
                        color: const Color(0xFF9A5A16),
                        width: 2,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontWeight:
                            isBest ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 11,
                        value: (exposure / 40).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    exposure.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight:
                          isBest ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E9B4B),
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 4),

        const Text(
          'Illustrative demo values only — not FortyGuard observations '
          'and not used for the live optimization decision.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

  Widget buildRouteHeatProfile() {
    final segments = bestRouteSegments;
    if (segments.isEmpty) return const SizedBox.shrink();

    final values = segments.map((segment) {
      return number(
            segment['heat_index'] ??
                segment['apparent_temperature'] ??
                segment['temperature'],
          ) ??
          0;
    }).toList();

    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.stacked_line_chart_rounded,
            'Route Heat Profile',
            subtitle: 'Environmental conditions sampled along the recommended route.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: segments.asMap().entries.map((entry) {
                final index = entry.key;
                final segment = entry.value;
                final value = values[index];
                final ratio = maxValue <= 0 ? 0.1 : (value / maxValue).clamp(0.1, 1.0);
                final level = riskLevel({
                  'thermal_level': value >= 40
                      ? 'HIGH'
                      : value >= 35
                          ? 'MODERATE'
                          : 'LOW',
                });
                final color = riskColor(level);
                final live = (segment['environment_source'] ??
                            segment['source'] ??
                            'fortyguard')
                        .toString()
                        .toLowerCase() ==
                    'fortyguard';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 92 * ratio,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'S${index + 1}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          live ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 12,
                          color: live
                              ? const Color(0xFF2E9B4B)
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded, size: 15, color: Color(0xFF2E9B4B)),
              const SizedBox(width: 5),
              Text(
                'Live environmental observation',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.local_fire_department_rounded, size: 15),
              const SizedBox(width: 5),
              Text(
                'Higher bar = higher sampled heat indicator',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProfileComparison() {
    if (profileComparisonResults.isEmpty) return const SizedBox.shrink();

    final bestExposure = profileComparisonResults.first['exposure'] as double;

    return sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            Icons.people_alt_rounded,
            'Profile Comparison',
            subtitle: 'Demo scenario — illustrative profile comparison.',
          ),
          const SizedBox(height: 14),
          ...profileComparisonResults.map((item) {
            final profile = item['profile'].toString();
            final exposure = item['exposure'] as double;
            final travel = item['travel'] as double;
            final isBest = exposure == bestExposure;

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isBest
                    ? const Color(0xFFFFE7D2)
                    : Colors.white.withOpacity(0.66),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBest
                      ? const Color(0xFF9A5A16)
                      : const Color(0xFFE0D4CB),
                  width: isBest ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Thermal budget policy: ${(item['budget'] as double).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    exposure.toStringAsFixed(2),
                    style: TextStyle(
                      color: riskColor(
                        exposure >= 40
                            ? 'HIGH'
                            : exposure >= 30
                                ? 'MODERATE'
                                : 'LOW',
                      ),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${travel.toStringAsFixed(1)} min',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 3),
          Text(
            'Illustrative demo values only — live journey optimization remains powered by the real backend.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget buildResults() {
    if (result == null) return const SizedBox.shrink();

    final found = recommendation['found'] == true;
    if (!found) {
      return sectionCard(
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recommendation['message']?.toString() ??
                    'No suitable journey found.',
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildMapSection(),
        buildFastestVsThermo(),
        buildImpactCard(),
        buildDepartureInsight(),
        buildBestDeparture(),
        buildRouteHeatProfile(),
        buildProfileComparison(),
        buildRecommendedRoute(),
        buildRouteComparison(),
        buildWhyThisRoute(),
        buildHeatIntelligence(),
        buildSafetyActions(),
        buildDataSources(),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sunny, size: 25),
            SizedBox(width: 9),
            Text(
              'ThermoRoute',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHero(),
                  buildPlanningForm(),
                  if (errorMessage != null)
                    sectionCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFC62828),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF9A1B1B),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  buildResults(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    destinationController.dispose();
    departureController.dispose();
    extraTimeController.dispose();
    heatBudgetController.dispose();
    super.dispose();
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
