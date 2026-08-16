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

const String apiBaseUrl = 'http://127.0.0.1:8001';

const LatLng defaultStart = LatLng(
  12.93485,
  77.53214,
);

const LatLng defaultDestination = LatLng(
  12.90730,
  77.57313,
);

const Color thermoTeal = Color(0xFF0B5D5E);
const Color lightTeal = Color(0xFFE4F4EF);

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
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: thermoTeal,
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

  String departureTime = '16:00';
  double extraTime = 20;
  bool loading = false;

  @override
  void dispose() {
    fromController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // CALL FASTAPI
  // POST /api/optimize
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
      final uri = Uri.parse(
        '$apiBaseUrl/api/optimize',
      );

      final requestBody = {
        'from_location': from,
        'destination': destination,
        'departure_time': departureTime,
        'max_extra_time_percent':
            extraTime.round(),
      };

      final response = await http
          .post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ThermoRoute API error: '
              '${response.statusCode}\n'
              '${response.body}',
            ),
            duration: const Duration(seconds: 6),
          ),
        );

        return;
      }

      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid response from ThermoRoute API.',
            ),
          ),
        );

        return;
      }

      final result =
          Map<String, dynamic>.from(decoded);

      // --------------------------------------------------------
      // IMPORTANT:
      // The backend returns:
      //
      // recommendation -> selected route
      // options        -> Route A, Route B, Route C
      //
      // We display ALL options.
      // --------------------------------------------------------

      final rawOptions = result['options'];

      if (rawOptions is! List ||
          rawOptions.isEmpty) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'API returned no route options.',
            ),
          ),
        );

        return;
      }

      final options =
          <Map<String, dynamic>>[];

      for (int i = 0;
          i < rawOptions.length;
          i++) {
        final raw = rawOptions[i];

        if (raw is! Map) continue;

        final option =
            Map<String, dynamic>.from(raw);

        option['route'] =
            option['route']?.toString() ??
                'Route ${String.fromCharCode(65 + i)}';

        option['travel_time_min'] =
            _formatNumber(
          option['travel_time_min'],
          1,
        );

        option['distance_km'] =
            _formatNumber(
          option['distance_km'],
          2,
        );

        option['thermal_exposure'] =
            _formatNumber(
          option['thermal_exposure'],
          0,
        );

        option['valid'] =
            option['valid'] == true;

        option['within_time_limit'] =
            option['within_time_limit'] == true;

        option['within_exposure_budget'] =
            option['within_exposure_budget'] == true;

        option['recommended'] =
            option['recommended'] == true;

        options.add(option);
      }

      // --------------------------------------------------------
      // KEEP BACKEND'S RECOMMENDATION
      // --------------------------------------------------------

      final recommendation =
          result['recommendation'];

      if (recommendation is Map) {
        final recommendedRoute =
            recommendation['route']
                ?.toString()
                .toLowerCase();

        for (final option in options) {
          final route =
              option['route']
                  ?.toString()
                  .toLowerCase();

          option['recommended'] =
              route == recommendedRoute;
        }
      }

      // Put normalized options back.
      result['options'] = options;

      setState(() {
        loading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RouteResultsScreen(
            from: from,
            destination: destination,
            departureTime: departureTime,
            extraTime: extraTime,
            result: result,
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
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  String _formatNumber(
    dynamic value,
    int decimals,
  ) {
    if (value == null) return '--';

    if (value is num) {
      return value.toStringAsFixed(
        decimals,
      );
    }

    final parsed =
        double.tryParse(
      value.toString(),
    );

    if (parsed == null) {
      return value.toString();
    }

    return parsed.toStringAsFixed(
      decimals,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFE6F0EF),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: thermoTeal,
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
              const BoxConstraints(
            maxWidth: 700,
          ),
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                const Text(
                  'Move smarter.\nMove cooler.',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight:
                        FontWeight.bold,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Intelligent routing that considers '
                  'thermal exposure along your journey.',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                _InputCard(
                  title: 'Starting point',
                  icon: Icons.my_location,
                  controller:
                      fromController,
                ),

                const SizedBox(height: 14),

                _InputCard(
                  title: 'Destination',
                  icon:
                      Icons.location_on_outlined,
                  controller:
                      destinationController,
                ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // DEPARTURE TIME
                // ------------------------------------------------

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(18),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Departure time',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      DropdownButtonFormField<
                          String>(
                        value:
                            departureTime,
                        decoration:
                            const InputDecoration(
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '14:00',
                            child:
                                Text('2:00 PM'),
                          ),
                          DropdownMenuItem(
                            value: '16:00',
                            child:
                                Text('4:00 PM'),
                          ),
                          DropdownMenuItem(
                            value: '18:00',
                            child:
                                Text('6:00 PM'),
                          ),
                        ],
                        onChanged:
                            (value) {
                          if (value != null) {
                            setState(() {
                              departureTime =
                                  value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // EXTRA TIME
                // ------------------------------------------------

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(18),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
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
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  thermoTeal,
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
                            thermoTeal,
                        onChanged:
                            (value) {
                          setState(() {
                            extraTime =
                                value;
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
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        loading
                            ? null
                            : findBestRoute,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.route,
                          ),
                    label: Text(
                      loading
                          ? 'CALCULATING...'
                          : 'FIND BEST ROUTE',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          thermoTeal,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Thermal-aware route optimization',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
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

class _InputCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final TextEditingController controller;

  const _InputCard({
    required this.title,
    required this.icon,
    required this.controller,
  });

  @override
  Widget build(
      BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration:
            InputDecoration(
          labelText: title,
          prefixIcon: Icon(
            icon,
            color: thermoTeal,
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

class RouteResultsScreen
    extends StatefulWidget {
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
  State<RouteResultsScreen>
      createState() =>
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
  // GEOCODING
  // ==========================================================

  Future<LatLng?> geocodeLocation(
    String location,
  ) async {
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

      final response =
          await http.get(
        url,
        headers: const {
          'User-Agent':
              'ThermoRouteHackathonDemo/1.0',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data =
          jsonDecode(response.body);

      if (data is! List ||
          data.isEmpty) {
        return null;
      }

      final item =
          Map<String, dynamic>.from(
        data.first as Map,
      );

      final lat =
          double.tryParse(
        item['lat']?.toString() ??
            '',
      );

      final lon =
          double.tryParse(
        item['lon']?.toString() ??
            '',
      );

      if (lat == null ||
          lon == null) {
        return null;
      }

      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // MAP
  // ==========================================================

  Future<void> loadMapRoute() async {
    try {
      setState(() {
        mapLoading = true;
        mapError = null;
        routePoints = [];
      });

      final start =
          await geocodeLocation(
        widget.from,
      );

      final destination =
          await geocodeLocation(
        widget.destination,
      );

      final actualStart =
          start ?? defaultStart;

      final actualDestination =
          destination ??
              defaultDestination;

      final url = Uri.parse(
        'https://router.project-osrm.org'
        '/route/v1/driving/'
        '${actualStart.longitude},'
        '${actualStart.latitude};'
        '${actualDestination.longitude},'
        '${actualDestination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response =
          await http.get(
        url,
        headers: const {
          'User-Agent':
              'ThermoRouteHackathonDemo/1.0',
        },
      );

      List<LatLng> points = [];

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        if (data is Map &&
            data['routes'] is List &&
            (data['routes'] as List)
                .isNotEmpty) {
          final firstRoute =
              (data['routes'] as List)
                  .first;

          if (firstRoute is Map &&
              firstRoute['geometry']
                  is Map) {
            final geometry =
                firstRoute['geometry']
                    as Map;

            final coordinates =
                geometry['coordinates'];

            if (coordinates is List) {
              points = coordinates
                  .whereType<List>()
                  .where(
                    (p) => p.length >= 2,
                  )
                  .map(
                    (p) => LatLng(
                      (p[1] as num)
                          .toDouble(),
                      (p[0] as num)
                          .toDouble(),
                    ),
                  )
                  .toList();
            }
          }
        }
      }

      if (points.length < 2) {
        points = [
          actualStart,
          actualDestination,
        ];
      }

      if (!mounted) return;

      setState(() {
        startLocation =
            actualStart;
        destinationLocation =
            actualDestination;
        routePoints = points;
        mapLoading = false;

        if (start == null ||
            destination == null) {
          mapError =
              'Using demo coordinates for the map.';
        } else if (
            response.statusCode != 200) {
          mapError =
              'Road map service unavailable.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        startLocation =
            defaultStart;
        destinationLocation =
            defaultDestination;
        routePoints = [
          defaultStart,
          defaultDestination,
        ];
        mapLoading = false;
        mapError =
            'Map service unavailable. '
            'Showing demo route.';
      });
    }
  }

  Map<String, dynamic>
      get recommendation {
    final value =
        widget.result['recommendation'];

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return {};
  }

  List<Map<String, dynamic>>
      get options {
    final value =
        widget.result['options'];

    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) =>
                Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    }

    return [];
  }

  String display(
    dynamic value, [
    String fallback = '--',
  ]) {
    if (value == null) {
      return fallback;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty ||
        text == 'null') {
      return fallback;
    }

    return text;
  }

  // ==========================================================
  // BUILD RESULTS
  // ==========================================================

  @override
  Widget build(
      BuildContext context) {
    final rec = recommendation;

    final recommendedRoute =
        display(
      rec['route'],
      'Recommended Route',
    );

    final travelTime =
        display(
      rec['travel_time_min'],
    );

    final distance =
        display(
      rec['distance_km'],
    );

    final exposure =
        display(
      rec['thermal_exposure'],
    );

    final maxAllowed =
        display(
      widget.result[
          'max_allowed_time'],
    );

    final maxExtra =
        display(
      widget.result[
          'max_extra_time_percent'],
      widget.extraTime
          .round()
          .toString(),
    );

    final budget =
        display(
      widget.result[
          'thermal_exposure_budget'],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ThermoRoute',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
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
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${widget.from} → '
                  '${widget.destination}',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Departure: '
                  '${widget.departureTime}',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 20),

                _MapCard(
                  routePoints:
                      routePoints,
                  loading:
                      mapLoading,
                  start:
                      startLocation,
                  destination:
                      destinationLocation,
                  error:
                      mapError,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // RECOMMENDED
                // ==================================================

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    22,
                  ),
                  decoration:
                      BoxDecoration(
                    color: lightTeal,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color: thermoTeal,
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
                            Icons
                                .check_circle,
                            color:
                                thermoTeal,
                          ),
                          SizedBox(
                              width: 8),
                          Text(
                            'RECOMMENDED JOURNEY',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  thermoTeal,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 14),

                      Text(
                        recommendedRoute,
                        style:
                            const TextStyle(
                          fontSize: 27,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const SizedBox(
                          height: 8),

                      const Text(
                        'Selected by the ThermoRoute '
                        'optimization engine using '
                        'travel-time and thermal-exposure '
                        'constraints.',
                      ),

                      const SizedBox(
                          height: 20),

                      Wrap(
                        spacing: 30,
                        runSpacing: 18,
                        children: [
                          _InfoItem(
                            icon:
                                Icons
                                    .timer_outlined,
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
                                Icons
                                    .thermostat,
                            value:
                                exposure,
                            label:
                                'Thermal exposure',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 24),

                // ==================================================
                // ENGINE STATUS
                // ==================================================

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color:
                            Colors.green,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ThermoRoute optimization '
                          'engine successfully calculated '
                          'this recommendation.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 28),

                // ==================================================
                // THREE ROUTES
                // ==================================================

                const Text(
                  'Route analysis',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 14),

                if (options.isEmpty)
                  const Text(
                    'No routes returned.',
                  )
                else
                  Column(
                    children:
                        options.map(
                      (option) {
                        return _RouteCard(
                          route: display(
                            option[
                                'route'],
                            'Route',
                          ),
                          time: display(
                            option[
                                'travel_time_min'],
                          ),
                          distance:
                              display(
                            option[
                                'distance_km'],
                          ),
                          exposure:
                              display(
                            option[
                                'thermal_exposure'],
                          ),
                          reason:
                              display(
                            option[
                                'reason'],
                            'Route returned by '
                            'the optimization engine.',
                          ),
                          recommended:
                              option[
                                      'recommended'] ==
                                  true,
                          valid:
                              option[
                                      'valid'] ==
                                  true,
                          withinExposureBudget:
                              option[
                                      'within_exposure_budget'] ==
                                  true,
                        );
                      },
                    ).toList(),
                  ),

                const SizedBox(
                    height: 18),

                // ==================================================
                // DECISION
                // ==================================================

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
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
                                thermoTeal,
                          ),
                          SizedBox(
                              width: 10),
                          Text(
                            'Optimization decision',
                            style:
                                TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 18),

                      _DecisionRow(
                        label:
                            'Maximum extra travel time',
                        value:
                            '$maxExtra%',
                      ),

                      const SizedBox(
                          height: 12),

                      _DecisionRow(
                        label:
                            'Maximum allowed time',
                        value:
                            '$maxAllowed min',
                      ),

                      const SizedBox(
                          height: 12),

                      _DecisionRow(
                        label:
                            'Recommended travel time',
                        value:
                            '$travelTime min',
                      ),

                      const SizedBox(
                          height: 12),

                      _DecisionRow(
                        label:
                            'Thermal exposure budget',
                        value:
                            budget,
                      ),

                      const SizedBox(
                          height: 18),

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              lightTeal,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child:
                            const Row(
                          children: [
                            Icon(
                              Icons
                                  .check_circle,
                              color:
                                  thermoTeal,
                              size: 20,
                            ),
                            SizedBox(
                                width: 8),
                            Expanded(
                              child: Text(
                                'Recommended route '
                                'stays within the '
                                'optimization limits.',
                                style:
                                    TextStyle(
                                  color:
                                      thermoTeal,
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

                const SizedBox(
                    height: 30),

                SizedBox(
                  width:
                      double.infinity,
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
                          thermoTeal,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                    height: 20),
              ],
            ),
          ),
        ),
      ),
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
  final bool withinExposureBudget;

  const _RouteCard({
    required this.route,
    required this.time,
    required this.distance,
    required this.exposure,
    required this.reason,
    required this.recommended,
    required this.valid,
    required this.withinExposureBudget,
  });

  @override
  Widget build(
      BuildContext context) {
    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: recommended
            ? lightTeal
            : Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: recommended
              ? thermoTeal
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
                    ? thermoTeal
                    : Colors.grey,
              ),

              const SizedBox(
                  width: 12),

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
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        thermoTeal,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child:
                      const Text(
                    'BEST',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(
              height: 18),

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
                  icon:
                      Icons.route,
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
                  value:
                      exposure,
                  label:
                      'Exposure',
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 14),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                valid &&
                        withinExposureBudget
                    ? Icons
                        .check_circle_outline
                    : Icons.info_outline,
                size: 20,
                color: valid &&
                        withinExposureBudget
                    ? Colors.green
                    : Colors.orange,
              ),

              const SizedBox(
                  width: 10),

              Expanded(
                child: Text(
                  reason,
                  style:
                      TextStyle(
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
  Widget build(
      BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color: thermoTeal,
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
              const SizedBox(
                  height: 3),
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
  Widget build(
      BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: thermoTeal,
        ),
        const SizedBox(
            width: 8),
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
  Widget build(
      BuildContext context) {
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
        const SizedBox(
            width: 12),
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

class _MapCard
    extends StatelessWidget {
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
  Widget build(
      BuildContext context) {
    final mapStart =
        start ?? defaultStart;

    final mapDestination =
        destination ??
            defaultDestination;

    final allPoints = <LatLng>[
      mapStart,
      mapDestination,
      ...routePoints,
    ];

    final bounds =
        LatLngBounds.fromPoints(
      allPoints,
    );

    return Container(
      height: 380,
      width: double.infinity,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options:
                MapOptions(
              initialCameraFit:
                  CameraFit.bounds(
                bounds: bounds,
                padding:
                    const EdgeInsets.all(
                  55,
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.thermoroute.app',
              ),

              if (routePoints.length >=
                  2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:
                          routePoints,
                      strokeWidth: 8,
                      color:
                          thermoTeal,
                      borderStrokeWidth:
                          2,
                      borderColor:
                          Colors.white,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  Marker(
                    point:
                        mapStart,
                    width: 82,
                    height: 82,
                    alignment:
                        Alignment.topCenter,
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        _MapLabel(
                          text:
                              'START',
                          color:
                              Colors.blue.shade700,
                        ),
                        const Icon(
                          Icons
                              .location_on,
                          color:
                              Colors.blue,
                          size: 40,
                        ),
                      ],
                    ),
                  ),

                  Marker(
                    point:
                        mapDestination,
                    width: 105,
                    height: 82,
                    alignment:
                        Alignment.topCenter,
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        _MapLabel(
                          text:
                              'DESTINATION',
                          color:
                              Colors.red.shade700,
                        ),
                        const Icon(
                          Icons
                              .location_on,
                          color:
                              Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (loading)
            Positioned(
              top: 14,
              right: 14,
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child:
                    const Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(
                        width: 8),
                    Text(
                      'Finding route...',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!loading &&
              error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child:
                  Container(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.95,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    Text(
                  error!,
                  style:
                      const TextStyle(
                    fontSize: 11,
                  ),
                  textAlign:
                      TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// MAP LABEL
// ============================================================

class _MapLabel
    extends StatelessWidget {
  final String text;
  final Color color;

  const _MapLabel({
    required this.text,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color: color,
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}