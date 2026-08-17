import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const ThermoRouteApp());
}

const thermoTeal = Color(0xFF0B5D5E);
const lightTeal = Color(0xFFE4F4EF);
const mapGreen = Color(0xFF18E06F);
const mapAmber = Color(0xFFFFB020);
const mapRed = Color(0xFFFF3B30);

// Phoenix demo coordinates.
const phoenixStart = LatLng(33.4484, -112.0740); // Downtown Phoenix
const phoenixDestination = LatLng(33.4342, -112.0118); // Sky Harbor area

class ThermoRouteApp extends StatelessWidget {
  const ThermoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThermoRoute',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: thermoTeal),
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
      ),
      home: const JourneySetupScreen(),
    );
  }
}

class JourneySetupScreen extends StatefulWidget {
  const JourneySetupScreen({super.key});

  @override
  State<JourneySetupScreen> createState() => _JourneySetupScreenState();
}

class _JourneySetupScreenState extends State<JourneySetupScreen> {
  final fromController = TextEditingController(text: 'Downtown Phoenix');
  final destinationController =
      TextEditingController(text: 'Phoenix Sky Harbor area');

  double extraTime = 20;
  String departureTime = '4:00 PM';
  bool isLoading = false;

  @override
  void dispose() {
    fromController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> findBestRoute() async {
    final from = fromController.text.trim();
    final destination = destinationController.text.trim();

    if (from.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both locations.')),
      );
      return;
    }

    setState(() => isLoading = true);

    Map<String, dynamic> result;

    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8000/api/optimize'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'from_location': from,
              'destination': destination,
              'departure_time': departureTime,
              'max_extra_time_percent': extraTime.round(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } else {
        result = demoResult();
      }
    } catch (_) {
      // The demo remains usable even when FastAPI is stopped.
      result = demoResult();
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteResultsScreen(
          from: from,
          destination: destination,
          departureTime: departureTime,
          extraTime: extraTime,
          result: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5F0EF),
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: thermoTeal,
              child: Icon(Icons.thermostat, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text(
              'ThermoRoute',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Move smarter.\nMove cooler.',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thermal-aware routing that compares travel time, distance and heat exposure.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0D8), Color(0xFFFFE2B5)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wb_sunny, color: Colors.deepOrange, size: 32),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thermal-aware routing',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text('Routes are compared using estimated heat exposure.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Plan your journey',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fromController,
                  decoration: InputDecoration(
                    labelText: 'From',
                    prefixIcon: const Icon(Icons.my_location),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: destinationController,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    prefixIcon: const Icon(Icons.location_on),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Preferred departure',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    setState(() {
                      departureTime =
                          departureTime == '4:00 PM' ? '6:00 PM' : '4:00 PM';
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time),
                        const SizedBox(width: 12),
                        Text(departureTime),
                        const Spacer(),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Maximum extra travel time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${extraTime.round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: thermoTeal,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: extraTime,
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: '${extraTime.round()}%',
                  onChanged: (value) => setState(() => extraTime = value),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : findBestRoute,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route),
                    label: Text(
                      isLoading ? 'CALCULATING...' : 'START DEMO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thermoTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Phoenix heat demo • live API when available',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RouteResultsScreen extends StatefulWidget {
  final String from;
  final String destination;
  final String departureTime;
  final double extraTime;
  final Map<String, dynamic> result;

  const RouteResultsScreen({
    super.key,
    required this.from,
    required this.destination,
    required this.departureTime,
    required this.extraTime,
    required this.result,
  });

  @override
  State<RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<RouteResultsScreen> {
  List<List<LatLng>> routeAlternatives = [];
  bool mapLoading = true;
  String mapStatus = 'Loading road alternatives...';

  @override
  void initState() {
    super.initState();
    loadRoadRoutes();
  }

  Future<void> loadRoadRoutes() async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${phoenixStart.longitude},${phoenixStart.latitude};'
        '${phoenixDestination.longitude},${phoenixDestination.latitude}'
        '?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(
        url,
        headers: const {'User-Agent': 'ThermoRoute/1.0 demo'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRoutes = (data['routes'] as List?) ?? [];
        final parsed = <List<LatLng>>[];

        for (final rawRoute in rawRoutes.take(3)) {
          final geometry = rawRoute['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List;
          final points = coords.map<LatLng>((p) {
            return LatLng(
              (p[1] as num).toDouble(),
              (p[0] as num).toDouble(),
            );
          }).toList();
          if (points.isNotEmpty) parsed.add(points);
        }

        if (parsed.isNotEmpty) {
          setState(() {
            routeAlternatives = parsed;
            mapLoading = false;
            mapStatus = '${parsed.length} road alternatives loaded';
          });
          return;
        }
      }
    } catch (_) {}

    // Visual fallback: three Phoenix road-like alternatives.
    setState(() {
      routeAlternatives = _demoMapRoutes();
      mapLoading = false;
      mapStatus = 'Demo road alternatives loaded';
    });
  }

  List<List<LatLng>> _demoMapRoutes() {
    return [
      [
        phoenixStart,
        const LatLng(33.4440, -112.0550),
        const LatLng(33.4390, -112.0340),
        const LatLng(33.4342, -112.0118),
      ],
      [
        phoenixStart,
        const LatLng(33.4550, -112.0530),
        const LatLng(33.4450, -112.0250),
        phoenixDestination,
      ],
      [
        phoenixStart,
        const LatLng(33.4300, -112.0650),
        const LatLng(33.4210, -112.0360),
        phoenixDestination,
      ],
    ];
  }

  int asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _safeRecommendation() {
    final raw = widget.result['recommendation'];
    if (raw is Map) {
      final current = Map<String, dynamic>.from(raw);
      final time = asInt(current['travel_time_min']);
      final distance = asDouble(current['distance_km']);
      final exposure = asDouble(current['thermal_exposure']);
      if (time > 0 || distance > 0 || exposure > 0) return current;
    }

    final rawOptions = widget.result['options'];
    if (rawOptions is List) {
      final options = rawOptions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final valid = options.where((e) {
        return e['valid'] == true ||
            e['within_exposure_budget'] == true ||
            e['recommended'] == true;
      }).toList();

      final pool = valid.isNotEmpty ? valid : options;
      if (pool.isNotEmpty) {
        pool.sort((a, b) {
          final ae = asDouble(a['thermal_exposure'] ?? a['exposure'], 999999);
          final be = asDouble(b['thermal_exposure'] ?? b['exposure'], 999999);
          return ae.compareTo(be);
        });
        return pool.first;
      }
    }

    return demoResult()['recommendation'] as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _routeOptions() {
    final raw = widget.result['options'];
    if (raw is List && raw.isNotEmpty) {
      final options = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (options.isNotEmpty) return options.take(3).toList();
    }

    return List<Map<String, dynamic>>.from(demoResult()['options'] as List);
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _safeRecommendation();
    final options = _routeOptions();

    final recommendedRoute =
        recommendation['route']?.toString() ?? 'Route B';
    final travelTime = asInt(recommendation['travel_time_min'], 23);
    final distance = asDouble(recommendation['distance_km'], 9.1);
    final exposure = asDouble(recommendation['thermal_exposure'], 7);

    final maxExtra = asDouble(
      widget.result['max_extra_time_percent'],
      widget.extraTime,
    );
    final fastestTime = asDouble(
      widget.result['fastest_time_min'],
      20,
    );
    final maxAllowed = asDouble(
      widget.result['max_allowed_time'],
      fastestTime * (1 + maxExtra / 100),
    );
    final exposureBudget = asDouble(
      widget.result['thermal_exposure_budget'],
      50,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5F0EF),
        title: const Text(
          'ThermoRoute',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your best journey',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.from} → ${widget.destination}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  'Departure: ${widget.departureTime}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 22),
                _MapCard(
                  routeAlternatives: routeAlternatives,
                  mapLoading: mapLoading,
                  mapStatus: mapStatus,
                ),
                const SizedBox(height: 10),
                Text(
                  'Green = cooler route  •  Amber = warmer route  •  Red = higher thermal exposure',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: lightTeal,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: thermoTeal, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: thermoTeal),
                          SizedBox(width: 8),
                          Text(
                            'RECOMMENDED JOURNEY',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: thermoTeal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recommendedRoute,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 28,
                        runSpacing: 16,
                        children: [
                          _InfoItem(
                            icon: Icons.timer_outlined,
                            value: '$travelTime min',
                            label: 'Travel time',
                          ),
                          _InfoItem(
                            icon: Icons.route,
                            value: '${distance.toStringAsFixed(1)} km',
                            label: 'Distance',
                          ),
                          _InfoItem(
                            icon: Icons.thermostat,
                            value: exposure.toStringAsFixed(0),
                            label: 'Thermal exposure',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Route analysis',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ThermoRoute compares route alternatives using travel time and thermal exposure.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < options.length; i++) ...[
                  _RouteComparisonCard(
                    routeName: options[i]['route']?.toString() ?? 'Route ${String.fromCharCode(65 + i)}',
                    time: asInt(options[i]['travel_time_min'] ?? options[i]['time'], 20 + i * 3),
                    distance: asDouble(options[i]['distance_km'] ?? options[i]['distance'], 8.4 + i * .7),
                    exposure: asDouble(options[i]['thermal_exposure'] ?? options[i]['exposure'], 80 - i * 11),
                    isRecommended: (options[i]['route']?.toString() ?? '') == recommendedRoute ||
                        options[i]['recommended'] == true,
                    maxAllowedTime: maxAllowed,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: thermoTeal),
                          SizedBox(width: 10),
                          Text(
                            'Optimization decision',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DecisionRow(
                        label: 'Maximum extra travel time',
                        value: '${maxExtra.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 10),
                      _DecisionRow(
                        label: 'Maximum allowed time',
                        value: '${maxAllowed.toStringAsFixed(2)} min',
                      ),
                      const SizedBox(height: 10),
                      _DecisionRow(
                        label: 'Recommended travel time',
                        value: '$travelTime min',
                      ),
                      const SizedBox(height: 10),
                      _DecisionRow(
                        label: 'Thermal exposure budget',
                        value: exposureBudget.toStringAsFixed(0),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: travelTime <= maxAllowed && exposure <= exposureBudget
                              ? lightTeal
                              : const Color(0xFFFFEEE9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              travelTime <= maxAllowed && exposure <= exposureBudget
                                  ? Icons.check_circle
                                  : Icons.warning_amber_rounded,
                              color: travelTime <= maxAllowed && exposure <= exposureBudget
                                  ? thermoTeal
                                  : Colors.deepOrange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                travelTime <= maxAllowed && exposure <= exposureBudget
                                    ? 'Recommended route stays within the optimization limits.'
                                    : 'Recommended route exceeds one of the optimization limits.',
                                style: TextStyle(
                                  color: travelTime <= maxAllowed && exposure <= exposureBudget
                                      ? thermoTeal
                                      : Colors.deepOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: thermoTeal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$recommendedRoute was selected using the route comparison, travel-time constraint and estimated thermal exposure. The red route represents the higher-heat alternative that should be avoided when a cooler valid route is available.',
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  title: const Text(
                    'View API response',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.black87,
                      child: SelectableText(
                        JsonEncoder.withIndent('  ').convert(widget.result),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('PLAN ANOTHER JOURNEY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: thermoTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final List<List<LatLng>> routeAlternatives;
  final bool mapLoading;
  final String mapStatus;

  const _MapCard({
    required this.routeAlternatives,
    required this.mapLoading,
    required this.mapStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
         ColorFiltered(
           colorFilter: const ColorFilter.matrix([
                 .65, 0, 0, 0, 0,
                 0, .65, 0, 0, 0,
                 0, 0, .65, 0, 0,
                0, 0, 0, 1, 0,
  ]),
  child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(33.441, -112.045),
                initialZoom: 12.8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.thermoroute.app',
                ),
                if (routeAlternatives.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (int i = 0; i < routeAlternatives.length; i++)
                        Polyline(
                          points: routeAlternatives[i],
                          strokeWidth: i == 0 ? 7 : 6,
                          color: i == 0
                              ? mapGreen
                              : i == 1
                                  ? mapAmber
                                  : mapRed,
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: phoenixStart,
                      width: 90,
                      height: 70,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on, color: mapGreen, size: 44),
                          Text(
                            'START',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Marker(
                      point: phoenixDestination,
                      width: 100,
                      height: 70,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on, color: mapRed, size: 44),
                          Text(
                            'DESTINATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _MapPill(
              icon: Icons.alt_route,
              text: mapLoading ? 'Loading routes...' : mapStatus,
            ),
          ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.84),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  _LegendDot(color: mapGreen, label: 'Cooler'),
                  SizedBox(width: 12),
                  _LegendDot(color: mapAmber, label: 'Warm'),
                  SizedBox(width: 12),
                  _LegendDot(color: mapRed, label: 'Hotter'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MapPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.84),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: mapGreen, size: 18),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 2),
        Icon(icon, color: thermoTeal, size: 21),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteComparisonCard extends StatelessWidget {
  final String routeName;
  final int time;
  final double distance;
  final double exposure;
  final bool isRecommended;
  final double maxAllowedTime;

  const _RouteComparisonCard({
    required this.routeName,
    required this.time,
    required this.distance,
    required this.exposure,
    required this.isRecommended,
    required this.maxAllowedTime,
  });

  @override
  Widget build(BuildContext context) {
    final overTime = time > maxAllowedTime;
    final overExposure = exposure > 50;
    final border = isRecommended ? thermoTeal : Colors.grey.shade300;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isRecommended ? lightTeal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: isRecommended ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isRecommended ? Icons.check_circle : Icons.alt_route,
                color: isRecommended ? thermoTeal : Colors.black54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  routeName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: thermoTeal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(Icons.access_time, '$time min', 'Travel time'),
              const SizedBox(width: 18),
              _Metric(Icons.route, '${distance.toStringAsFixed(1)} km', 'Distance'),
              const SizedBox(width: 18),
              _Metric(Icons.thermostat, exposure.toStringAsFixed(0), 'Exposure'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isRecommended && !overTime && !overExposure
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                size: 17,
                color: isRecommended && !overTime && !overExposure
                    ? Colors.green
                    : Colors.deepOrange,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isRecommended
                      ? 'Selected by the optimization engine.'
                      : overExposure
                          ? 'Higher thermal exposure — hotter alternative.'
                          : overTime
                              ? 'Exceeds the travel-time limit.'
                              : 'Alternative route for comparison.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: thermoTeal, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
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

class _DecisionRow extends StatelessWidget {
  final String label;
  final String value;

  const _DecisionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}

Map<String, dynamic> demoResult() {
  return {
    'recommendation': {
      'route': 'Route B',
      'travel_time_min': 23,
      'distance_km': 9.1,
      'thermal_exposure': 7,
      'recommended': true,
      'valid': true,
    },
    'fastest_time_min': 20,
    'max_extra_time_percent': 20,
    'max_allowed_time': 24,
    'thermal_exposure_budget': 50,
    'options': [
      {
        'route': 'Route A',
        'travel_time_min': 20,
        'distance_km': 8.4,
        'thermal_exposure': 80,
        'valid': false,
        'recommended': false,
      },
      {
        'route': 'Route B',
        'travel_time_min': 23,
        'distance_km': 9.1,
        'thermal_exposure': 7,
        'valid': true,
        'recommended': true,
      },
      {
        'route': 'Route C',
        'travel_time_min': 26,
        'distance_km': 10.0,
        'thermal_exposure': 6,
        'valid': false,
        'recommended': false,
      },
    ],
  };
}
