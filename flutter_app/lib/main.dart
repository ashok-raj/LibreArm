import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/bp_client.dart';
import 'services/health_service.dart';
import 'models/bp_reading.dart';

void main() {
  runApp(const LibreArmApp());
}

class LibreArmApp extends StatelessWidget {
  const LibreArmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BPClient()),
        Provider(create: (_) => HealthService()),
      ],
      child: MaterialApp(
        title: 'LibreArm',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _autoSaveToHealth = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final health = context.read<HealthService>();
    final bp = context.read<BPClient>();

    await health.requestAuth();

    bp.onFinalReading = (reading) {
      if (_autoSaveToHealth) {
        health.saveBP(
          systolic: reading.sys,
          diastolic: reading.dia,
          bpm: reading.hr,
          date: DateTime.now(),
        );
      }
    };

    bp.startConnect(timeout: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Pressure'),
        centerTitle: true,
      ),
      body: Consumer<BPClient>(
        builder: (context, bp, _) {
          return SafeArea(
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Header
                        _buildHeader(bp),

                        const SizedBox(height: 24),

                        // Last reading card
                        if (bp.lastReading != null) _buildReadingCard(bp.lastReading!),

                        const SizedBox(height: 24),

                        // Start/Stop button
                        _buildMeasureButton(bp),

                        const SizedBox(height: 16),

                        // Save to Health toggle
                        SwitchListTile(
                          title: const Text('Save to Apple Health'),
                          value: _autoSaveToHealth,
                          onChanged: bp.isMeasuring
                              ? null
                              : (value) => setState(() => _autoSaveToHealth = value),
                        ),

                        // Average mode toggle
                        SwitchListTile(
                          title: const Text('Average (3 readings)'),
                          value: bp.measurementMode == MeasurementMode.average3,
                          onChanged: bp.isMeasuring
                              ? null
                              : (value) {
                                  bp.measurementMode =
                                      value ? MeasurementMode.average3 : MeasurementMode.single;
                                },
                        ),

                        // Delay slider (only in average mode)
                        if (bp.measurementMode == MeasurementMode.average3)
                          _buildDelaySlider(bp),

                        const SizedBox(height: 16),

                        // Retry button
                        if (!bp.isConnected)
                          TextButton(
                            onPressed: () => bp.startConnect(timeout: 30),
                            child: const Text('Retry Connect'),
                          ),
                      ],
                    ),
                  ),
                ),

                // Fixed footer at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFooter(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BPClient bp) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/LibreArmIconWhite.png',
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.screen,
              color: Colors.red.shade600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'LibreArm',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          bp.status,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReadingCard(BPReading reading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${reading.sys.toInt()}/${reading.dia.toInt()} mmHg',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (reading.map != null) ...[
                Icon(Icons.speed, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${reading.map!.toInt()} MAP',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
              ],
              if (reading.hr != null) ...[
                Icon(Icons.favorite, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${reading.hr!.toInt()} bpm',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureButton(BPClient bp) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: (!bp.canMeasure && !bp.isMeasuring)
            ? null
            : () {
                if (bp.isMeasuring) {
                  bp.cancelMeasurement();
                } else {
                  bp.startMeasurement();
                }
              },
        style: FilledButton.styleFrom(
          backgroundColor: bp.isMeasuring ? Colors.red : Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          bp.isMeasuring ? 'Stop Measurement' : 'Start Measurement',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDelaySlider(BPClient bp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delay between readings'),
              Text(
                '${bp.delayBetweenRuns.toInt()}s',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: bp.delayBetweenRuns,
              min: 15,
              max: 60,
              divisions: 9,
              label: '${bp.delayBetweenRuns.toInt()}s',
              onChanged: bp.isMeasuring
                  ? null
                  : (value) {
                      bp.delayBetweenRuns = value;
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Developed by Paul Taylor',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          'Flutter Code by Ashok Raj',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            // Open GitHub link
          },
          child: Text(
            'GitHub: ashok-raj/LibreArm',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 2.0',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
