import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ThermoRouteApp());
}

class ThermoRouteApp extends StatelessWidget {
  const ThermoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThermoRoute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        useMaterial3: true,
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
  final TextEditingController fromController =
      TextEditingController(text: 'Phoenix, Arizona');

  final TextEditingController destinationController =
      TextEditingController(text: 'Scottsdale, Arizona');

  final TextEditingController departureController =
      TextEditingController(text: '14:00');

  final TextEditingController extraTimeController =
      TextEditingController(text: '30');

  final TextEditingController heatBudgetController =
      TextEditingController(text: '100');

  bool loading = false;
  String? errorMessage;
  Map<String, dynamic>? result;

  // Windows Flutter app + FastAPI on same computer.
 static const String apiUrl =
    'http://127.0.0.1:8000/api/optimize';
Future<void> optimizeJourney() async {
  setState(() {
    loading = true;
    errorMessage = null;
    result = null;
  });

  try {
    final body = {
      'from_location': fromController.text.trim(),
      'destination': destinationController.text.trim(),
      'departure_time': departureController.text.trim(),
      'max_extra_time_percent':
          double.tryParse(
            extraTimeController.text.trim(),
          ) ??
          30,
      'thermal_exposure_budget':
          double.tryParse(
            heatBudgetController.text.trim(),
          ) ??
          100,
    };

    debugPrint('THERMOROUTE REQUEST');
    debugPrint('URL: $apiUrl');
    debugPrint('BODY: $body');

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 180),
        );

    debugPrint(
      'THERMOROUTE STATUS: ${response.statusCode}',
    );

    debugPrint(
      'THERMOROUTE RESPONSE: ${response.body}',
    );

    if (!mounted) return;

    // Stop the spinner immediately after receiving
    // the HTTP response.
    setState(() {
      loading = false;
    });

    if (response.statusCode != 200) {
      setState(() {
        errorMessage =
            'Server returned HTTP ${response.statusCode}';
      });
      return;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      setState(() {
        errorMessage =
            'Invalid response format from server.';
      });
      return;
    }

    setState(() {
      result = decoded;
      errorMessage = null;
    });

    debugPrint(
      'THERMOROUTE RESULT UPDATED',
    );

  } catch (e, stackTrace) {
    debugPrint(
      'THERMOROUTE ERROR: $e',
    );

    debugPrint(
      '$stackTrace',
    );

    if (!mounted) return;

    setState(() {
      loading = false;
      errorMessage =
          'Unable to connect to ThermoRoute backend.\n\n$e';
    });
  }
}
  Color levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return Colors.green;
      case 'MODERATE':
        return Colors.orange;
      case 'HIGH':
        return Colors.deepOrange;
      case 'EXTREME':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData levelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return Icons.check_circle;
      case 'MODERATE':
        return Icons.warning_amber_rounded;
      case 'HIGH':
        return Icons.local_fire_department;
      case 'EXTREME':
        return Icons.dangerous;
      default:
        return Icons.info;
    }
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              icon == null ? null : Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget buildRecommendedRoute(
    Map<String, dynamic> recommendation,
  ) {
    final best =
        recommendation['best_journey'] as Map<String, dynamic>?;

    if (best == null) {
      return const SizedBox.shrink();
    }

    final route =
        (best['route'] as List?)?.map((e) => e.toString()).toList() ??
            [];

    final exposure =
        (best['thermal_exposure'] ?? 0).toString();

    final level =
        (best['thermal_level'] ?? 'UNKNOWN').toString();

    final explanation =
        (best['thermal_explanation'] ?? '').toString();

    final travelTime =
        (best['travel_time_min'] ?? 0).toString();

    final distance =
        (best['distance_km'] ?? 0).toString();

    final color = levelColor(level);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.route,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Recommended Journey',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  levelIcon(level),
                  color: color,
                  size: 30,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withValues(alpha: 0.10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.thermostat,
                    color: color,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thermal Exposure',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$exposure / 100',
                        style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Route',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            ...route.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final location = entry.value;

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor:
                              Theme.of(context)
                                  .colorScheme
                                  .primary,
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
                            color: Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 2),
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 30),

            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.timer,
                    'Travel Time',
                    '$travelTime min',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    Icons.straighten,
                    'Distance',
                    '$distance km',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 23),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildAlternativeRoutes(
    Map<String, dynamic> recommendation,
  ) {
    final options =
        recommendation['options'] as List? ?? [];

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),

        const Text(
          'Available Routes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        ...options.map((item) {
          final option =
              item as Map<String, dynamic>;

          final route =
              (option['route'] as List?)
                      ?.map((e) => e.toString())
                      .join(' → ') ??
                  '';

          final level =
              (option['thermal_level'] ?? 'UNKNOWN')
                  .toString();

          final exposure =
              (option['thermal_exposure'] ?? 0)
                  .toString();

          final time =
              (option['travel_time_min'] ?? 0)
                  .toString();

          final distance =
              (option['distance_km'] ?? 0)
                  .toString();

          final color = levelColor(level);

          return Card(
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    route,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text('⏱ $time min'),
                      Text('📍 $distance km'),
                      Text(
                        '🌡 $exposure',
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        level,
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget buildResult() {
    if (result == null) {
      return const SizedBox.shrink();
    }

    final recommendation =
        result!['recommendation']
            as Map<String, dynamic>?;

    if (recommendation == null) {
      return const SizedBox.shrink();
    }

    final found =
        recommendation['found'] == true;

    if (!found) {
      return Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            recommendation['message']?.toString() ??
                'No suitable journey found.',
          ),
        ),
      );
    }

    return Column(
      children: [
        buildRecommendedRoute(
          recommendation,
        ),
        buildAlternativeRoutes(
          recommendation,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sunny),
            SizedBox(width: 10),
            Text(
              'ThermoRoute',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 850,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heat-aware journey planning',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Find a route that balances travel time '
                    'with thermal exposure.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          inputField(
                            label: 'From',
                            controller:
                                fromController,
                            icon: Icons.location_on,
                          ),

                          inputField(
                            label: 'Destination',
                            controller:
                                destinationController,
                            icon:
                                Icons.location_pin,
                          ),

                          inputField(
                            label: 'Departure Time',
                            controller:
                                departureController,
                            icon: Icons.access_time,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: inputField(
                                  label:
                                      'Max Extra Time %',
                                  controller:
                                      extraTimeController,
                                  icon:
                                      Icons.more_time,
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: inputField(
                                  label:
                                      'Thermal Budget',
                                  controller:
                                      heatBudgetController,
                                  icon:
                                      Icons.thermostat,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: loading
                                  ? null
                                  : optimizeJourney,
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
                                    ? 'Optimizing...'
                                    : 'Optimize Journey',
                                style:
                                    const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (errorMessage != null)
                    Card(
                      margin:
                          const EdgeInsets.only(top: 20),
                      color: Colors.red.shade50,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  color:
                                      Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  buildResult(),
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