import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const ThermoRouteApp());
}

// ============================================================
// CONFIG
// ============================================================

const String apiBaseUrl = 'http://127.0.0.1:8000';

const LatLng defaultStart = LatLng(
  12.93485,
  77.53214,
);

const LatLng defaultDestination = LatLng(
  12.90730,
  77.57313,
);

// ============================================================
// APP
// ============================================================

class ThermoRouteApp extends StatelessWidget {
  const ThermoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThermoRoute',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor:
            const Color(0xFFF5F8F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5D5E),
        ),
      ),
      home: const JourneySetupScreen(),
    );
  }
}

// ============================================================
// JOURNEY SETUP
// ============================================================

class JourneySetupScreen extends StatefulWidget {
  const JourneySetupScreen({super.key});

  @override
  State<JourneySetupScreen> createState() =>
      _JourneySetupScreenState();
}

class _JourneySetupScreenState
    extends State<JourneySetupScreen> {
  final TextEditingController fromController =
      TextEditingController(
    text: 'PES University Ring Road Campus, Bengaluru',
  );

  final TextEditingController destinationController =
      TextEditingController(
    text: 'JP Nagar Metro Station, Bengaluru',
  );

  double extraTime = 20;

  String departureTime = '16:00';

  bool loading = false;

  @override
  void dispose() {
    fromController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // FIND BEST ROUTE
  // ==========================================================

  Future<void> findBestRoute() async {
    final from = fromController.text.trim();
    final destination =
        destinationController.text.trim();

    if (from.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter both locations.',
          ),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/optimize'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from_location': from,
          'destination': destination,
          'departure_time': departureTime,
          'max_extra_time_percent':
              extraTime.round(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'API error: ${response.statusCode}\n'
              '${response.body}',
            ),
          ),
        );

        return;
      }

      final data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      setState(() {
        loading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteResultsScreen(
            from: from,
            destination: destination,
            departureTime: departureTime,
            extraTime: extraTime,
            result: data,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect to ThermoRoute API.\n$e',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B5D5E),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.thermostat,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ThermoRoute',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                  'Intelligent routing that considers '
                  'thermal exposure along your journey.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                _InputCard(
                  title: 'Starting point',
                  icon: Icons.my_location,
                  controller: fromController,
                ),

                const SizedBox(height: 14),

                _InputCard(
                  title: 'Destination',
                  icon: Icons.location_on_outlined,
                  controller:
                      destinationController,
                ),

                const SizedBox(height: 20),

                // =================================================
                // DEPARTURE TIME
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Departure time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: departureTime,
                        decoration:
                            const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '14:00',
                            child: Text('2:00 PM'),
                          ),
                          DropdownMenuItem(
                            value: '16:00',
                            child: Text('4:00 PM'),
                          ),
                          DropdownMenuItem(
                            value: '18:00',
                            child: Text('6:00 PM'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              departureTime = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // =================================================
                // EXTRA TIME
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Maximum extra travel time',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${extraTime.round()}%',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF0B5D5E),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: extraTime,
                        min: 0,
                        max: 50,
                        divisions: 10,
                        activeColor:
                            const Color(0xFF0B5D5E),
                        onChanged: (value) {
                          setState(() {
                            extraTime = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        loading ? null : findBestRoute,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route),
                    label: Text(
                      loading
                          ? 'CALCULATING...'
                          : 'FIND BEST ROUTE',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF0B5D5E),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Thermal-aware route optimization',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
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

// ============================================================
// INPUT CARD
// ============================================================

class _InputCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final TextEditingController controller;

  const _InputCard({
    required this.title,
    required this.icon,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: title,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF0B5D5E),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ============================================================
// RESULTS SCREEN
// ============================================================

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
  State<RouteResultsScreen> createState() =>
      _RouteResultsScreenState();
}

class _RouteResultsScreenState
    extends State<RouteResultsScreen> {
  List<LatLng> routePoints = [];

  LatLng? startLocation;
  LatLng? destinationLocation;

  bool mapLoading = true;

  String? mapError;

  @override
  void initState() {
    super.initState();
    loadMapRoute();
  }

  // ==========================================================
  // GEOCODE USER LOCATIONS
  // ==========================================================

  Future<LatLng?> geocodeLocation(
      String location) async {
    try {
      final encoded =
          Uri.encodeQueryComponent(
        '$location, Bengaluru, India',
      );

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$encoded'
        '&format=json'
        '&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'ThermoRouteHackathonDemo/1.0',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final List<dynamic> data =
          jsonDecode(response.body)
              as List<dynamic>;

      if (data.isEmpty) {
        return null;
      }

      final item =
          data.first as Map<String, dynamic>;

      final lat =
          double.tryParse(
        item['lat']?.toString() ?? '',
      );

      final lon =
          double.tryParse(
        item['lon']?.toString() ?? '',
      );

      if (lat == null || lon == null) {
        return null;
      }

      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // LOAD ACTUAL MAP ROUTE
  // ==========================================================

  Future<void> loadMapRoute() async {
    try {
      setState(() {
        mapLoading = true;
        mapError = null;
        routePoints = [];
      });

      // Find the real coordinates for the entered locations.
      final start = await geocodeLocation(widget.from);
      final destination = await geocodeLocation(widget.destination);

      // Fall back to the demo coordinates if geocoding fails.
      final actualStart = start ?? defaultStart;
      final actualDestination =
          destination ?? defaultDestination;

      // Get the actual road geometry from OSRM.
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/'
        'driving/'
        '${actualStart.longitude},${actualStart.latitude};'
        '${actualDestination.longitude},'
        '${actualDestination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ThermoRouteHackathonDemo/1.0',
        },
      );

      List<LatLng> points = [];

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final routes = data['routes'];

        if (routes is List && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          points = coordinates.map<LatLng>((point) {
            return LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            );
          }).toList();
        }
      }

      // If the routing service fails, keep a visible fallback line.
      if (points.length < 2) {
        points = [
          actualStart,
          actualDestination,
        ];
      }

      if (!mounted) return;

      setState(() {
        startLocation = actualStart;
        destinationLocation = actualDestination;
        routePoints = points;
        mapLoading = false;

        if (start == null || destination == null) {
          mapError =
              'Using demo coordinates for one or more locations.';
        } else if (response.statusCode != 200) {
          mapError =
              'Road routing service unavailable. Showing a direct route.';
        } else {
          mapError = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        startLocation = defaultStart;
        destinationLocation = defaultDestination;
        routePoints = [
          defaultStart,
          defaultDestination,
        ];
        mapLoading = false;
        mapError =
            'Map service unavailable. Showing demo route.';
      });
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final recommendation =
        widget.result['recommendation'] is Map
            ? Map<String, dynamic>.from(
                widget.result['recommendation'],
              )
            : <String, dynamic>{};

    final travelTime =
        recommendation['travel_time_min']
                ?.toString() ??
            '0';

    final distance =
        recommendation['distance_km']
                ?.toString() ??
            '0';

    final exposure =
        recommendation['thermal_exposure']
                ?.toString() ??
            '0';

    final maxAllowed =
        widget.result['max_allowed_time']
                ?.toString() ??
            '--';

    final maxExtra =
        widget.result[
                    'max_extra_time_percent']
                ?.toString() ??
            widget.extraTime.round().toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ThermoRoute',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1000,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your best journey',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${widget.from} → '
                  '${widget.destination}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Departure: '
                  '${widget.departureTime}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // REAL MAP
                // =================================================

                _MapCard(
                  routePoints: routePoints,
                  loading: mapLoading,
                  start: startLocation,
                  destination: destinationLocation,
                  error: mapError,
                ),

                const SizedBox(height: 24),

                // =================================================
                // RECOMMENDED JOURNEY
                // =================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE4F4EF),
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          const Color(0xFF0B5D5E),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color:
                                Color(0xFF0B5D5E),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'RECOMMENDED JOURNEY',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(
                                      0xFF0B5D5E),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Recommended Route',
                        style:
                            TextStyle(
                          fontSize: 27,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Selected using travel-time '
                        'constraints and estimated '
                        'thermal exposure.',
                      ),

                      const SizedBox(height: 20),

                      Wrap(
                        spacing: 30,
                        runSpacing: 18,
                        children: [
                          _InfoItem(
                            icon:
                                Icons.timer_outlined,
                            value:
                                '$travelTime min',
                            label:
                                'Travel time',
                          ),
                          _InfoItem(
                            icon:
                                Icons.route,
                            value:
                                '$distance km',
                            label:
                                'Distance',
                          ),
                          _InfoItem(
                            icon:
                                Icons.thermostat,
                            value:
                                exposure,
                            label:
                                'Relative thermal exposure',
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // =================================================
                      // SCORE EXPLANATION
                      // =================================================

                      Container(
                        padding:
                            const EdgeInsets.all(14),
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withOpacity(0.7),
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons
                                  .info_outline,
                              color:
                                  Color(
                                      0xFF0B5D5E),
                            ),
                            SizedBox(
                                width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    'What does this score mean?',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                  SizedBox(
                                      height: 5),
                                  Text(
                                    'This is a relative thermal '
                                    'exposure score, not a medical '
                                    'risk measurement. It combines '
                                    'temperature intensity with the '
                                    'time spent along route segments.',
                                    style:
                                        TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =================================================
                // ENGINE STATUS
                // =================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ThermoRoute optimization engine '
                          'successfully calculated this '
                          'recommendation.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // =================================================
                // ROUTE ANALYSIS
                // =================================================

                const Text(
                  'Route analysis',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                _AllRouteCards(
                  result: widget.result,
                ),

                const SizedBox(height: 18),

                // =================================================
                // OPTIMIZATION DECISION
                // =================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color:
                                Color(
                                    0xFF0B5D5E),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Optimization decision',
                            style:
                                TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _DecisionRow(
                        label:
                            'Maximum extra travel time',
                        value:
                            '$maxExtra%',
                      ),

                      const SizedBox(height: 12),

                      _DecisionRow(
                        label:
                            'Maximum allowed time',
                        value:
                            '$maxAllowed min',
                      ),

                      const SizedBox(height: 12),

                      _DecisionRow(
                        label:
                            'Recommended travel time',
                        value:
                            '$travelTime min',
                      ),

                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(12),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                                  0xFFE4F4EF),
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons
                                  .check_circle,
                              color:
                                  Color(
                                      0xFF0B5D5E),
                              size: 20,
                            ),
                            SizedBox(
                                width: 8),
                            Expanded(
                              child: Text(
                                'Recommended route stays '
                                'within your travel-time limit.',
                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                          0xFF0B5D5E),
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // =================================================
                // PLAN ANOTHER
                // =================================================

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child:
                      ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                    ),
                    label: const Text(
                      'PLAN ANOTHER JOURNEY',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                              0xFF0B5D5E),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ALL ROUTE CARDS
// ============================================================

class _AllRouteCards
    extends StatelessWidget {
  final Map<String, dynamic> result;

  const _AllRouteCards({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final rawOptions =
        result['options'];

    // Use every option returned by backend.
    if (rawOptions is List &&
        rawOptions.isNotEmpty) {
      return Column(
        children:
            rawOptions.map<Widget>((item) {
          final option =
              Map<String, dynamic>.from(
            item,
          );

          return _RouteCard(
            route:
                option['route']
                        ?.toString() ??
                    'Route',
            time:
                option['travel_time_min']
                        ?.toString() ??
                    '0',
            distance:
                option['distance_km']
                        ?.toString() ??
                    '0',
            exposure:
                option['thermal_exposure']
                        ?.toString() ??
                    '0',
            reason:
                option['reason']
                        ?.toString() ??
                    '',
            recommended:
                option['recommended'] == true,
            valid:
                option['valid'] == true,
          );
        }).toList(),
      );
    }

    // Fallback for current API response.
    final recommendation =
        result['recommendation'] is Map
            ? Map<String, dynamic>.from(
                result['recommendation'],
              )
            : <String, dynamic>{};

    return _RouteCard(
      route: 'Recommended Route',
      time:
          recommendation[
                      'travel_time_min']
                  ?.toString() ??
              '0',
      distance:
          recommendation['distance_km']
                  ?.toString() ??
              '0',
      exposure:
          recommendation[
                      'thermal_exposure']
                  ?.toString() ??
              '0',
      reason:
          'Selected using the optimization constraints '
          'and estimated thermal exposure.',
      recommended: true,
      valid: true,
    );
  }
}

// ============================================================
// ROUTE CARD
// ============================================================

class _RouteCard
    extends StatelessWidget {
  final String route;
  final String time;
  final String distance;
  final String exposure;
  final String reason;
  final bool recommended;
  final bool valid;

  const _RouteCard({
    required this.route,
    required this.time,
    required this.distance,
    required this.exposure,
    required this.reason,
    required this.recommended,
    required this.valid,
  });

  @override
  Widget build(BuildContext context) {
    const teal =
        Color(0xFF0B5D5E);

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: recommended
            ? const Color(0xFFE4F4EF)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: recommended
              ? teal
              : Colors.grey.shade300,
          width:
              recommended ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                recommended
                    ? Icons.check_circle
                    : Icons.alt_route,
                color: recommended
                    ? teal
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  route,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              if (recommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: teal,
                    borderRadius:
                        BorderRadius.circular(
                            20),
                  ),
                  child: const Text(
                    'BEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _RouteMetric(
                  icon:
                      Icons.access_time,
                  value:
                      '$time min',
                  label:
                      'Travel time',
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  icon: Icons.route,
                  value:
                      '$distance km',
                  label:
                      'Distance',
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  icon:
                      Icons.thermostat,
                  value: exposure,
                  label:
                      'Exposure',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                valid
                    ? Icons
                        .check_circle_outline
                    : Icons.info_outline,
                size: 20,
                color: valid
                    ? Colors.grey.shade600
                    : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  reason,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.35,
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

// ============================================================
// ROUTE METRIC
// ============================================================

class _RouteMetric
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _RouteMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color:
              const Color(0xFF0B5D5E),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// INFO ITEM
// ============================================================

class _InfoItem
    extends StatelessWidget {
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
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          color:
              const Color(0xFF0B5D5E),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// DECISION ROW
// ============================================================

class _DecisionRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _DecisionRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MAP CARD
// ============================================================

class _MapCard extends StatelessWidget {
  final List<LatLng> routePoints;
  final bool loading;
  final LatLng? start;
  final LatLng? destination;
  final String? error;

  const _MapCard({
    required this.routePoints,
    required this.loading,
    required this.start,
    required this.destination,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final mapStart = start ?? defaultStart;
    final mapDestination =
        destination ?? defaultDestination;

    // Include the endpoints and route geometry so the
    // complete journey fits inside the map.
    final allPoints = <LatLng>[
      mapStart,
      mapDestination,
      ...routePoints,
    ];

    final bounds = LatLngBounds.fromPoints(allPoints);

    return Container(
      height: 380,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(55),
              ),
            ),
            children: [
              // OpenStreetMap base map.
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.thermoroute.app',
              ),

              // Actual road route returned by OSRM.
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 8,
                      color: const Color(0xFF0B5D5E),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Start and destination markers.
              MarkerLayer(
                markers: [
                  Marker(
                    point: mapStart,
                    width: 82,
                    height: 82,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Text(
                            'START',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                  Marker(
                    point: mapDestination,
                    width: 105,
                    height: 82,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Text(
                            'DESTINATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Loading indicator.
          if (loading)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Finding route...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Route legend.
          if (!loading && routePoints.length >= 2)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route,
                      size: 18,
                      color: Color(0xFF0B5D5E),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Recommended route',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Fallback/service message.
          if (!loading && error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
