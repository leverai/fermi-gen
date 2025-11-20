import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/simple_percentile_text.dart';

class PercentileDemoApp extends StatelessWidget {
  const PercentileDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Percentile Text Demo',
      theme: ThemeData.dark(),
      home: const PercentileDemoPage(),
    );
  }
}

class PercentileDemoPage extends StatefulWidget {
  const PercentileDemoPage({super.key});

  @override
  State<PercentileDemoPage> createState() => _PercentileDemoPageState();
}

class _PercentileDemoPageState extends State<PercentileDemoPage> {
  int _percentile = 42;

  void _setPercentile(int value) {
    setState(() => _percentile = value.clamp(0, 100));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Percentile Text Demo')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SimplePercentileText(
                percentile: _percentile,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('0'),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 100,
                        divisions: 100,
                        value: _percentile.toDouble(),
                        label: _percentile.toString(),
                        onChanged: (v) => _setPercentile(v.round()),
                      ),
                    ),
                    const Text('100'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _setPercentile(5),
                    child: const Text('5th'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _setPercentile(50),
                    child: const Text('50th'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _setPercentile(95),
                    child: const Text('95th'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
