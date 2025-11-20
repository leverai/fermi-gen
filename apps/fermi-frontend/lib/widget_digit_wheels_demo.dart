import 'package:flutter/material.dart';
import 'widgets/digit_wheels.dart';

void main() {
  runApp(const DigitWheelsDemoApp());
}

class DigitWheelsDemoApp extends StatelessWidget {
  const DigitWheelsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigitWheels Demo',
      theme: ThemeData.light(),
      home: const DigitWheelsDemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DigitWheelsDemoScreen extends StatefulWidget {
  const DigitWheelsDemoScreen({super.key});

  @override
  State<DigitWheelsDemoScreen> createState() => _DigitWheelsDemoScreenState();
}

class _DigitWheelsDemoScreenState extends State<DigitWheelsDemoScreen> {
  final DigitWheelsController _controller = DigitWheelsController();
  int _value = 123;
  final TextEditingController _text = TextEditingController(text: '123');

  void _syncFromText({bool animate = false}) {
    final parsed = int.tryParse(_text.text);
    if (parsed == null) return;
    final v = parsed.clamp(1, 999);
    if (animate) {
      _controller.animateTo(v, const Duration(milliseconds: 500));
    } else {
      _controller.jumpTo(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DigitWheels Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DigitWheels(
              initialValue: _value,
              controller: _controller,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 16),
            Text('Value: $_value', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _text,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Set 1..999',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => _syncFromText(animate: false),
                  child: const Text('Jump'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _syncFromText(animate: true),
                  child: const Text('Animate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
