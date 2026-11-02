import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AdvancedInAppReview _review;
  String _status = 'Complete tasks to become eligible for a review request.';

  @override
  void initState() {
    super.initState();
    _review =
        AdvancedInAppReview(
            onResult: (result) {
              if (mounted) setState(() => _status = result.toString());
            },
          )
          ..setMinDaysAfterInstall(0)
          ..setMinLaunchTimes(1)
          ..setMinSignificantEvents(3)
          ..setMinSecondsBeforeShowDialog(2);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _review.monitor();
    } catch (error) {
      if (mounted) setState(() => _status = 'Initialization failed: $error');
    }
  }

  Future<void> _completeTask() async {
    try {
      await _review.recordSignificantEvent();
      await _review.requestReviewIfEligible();
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not record task: $error');
    }
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Advanced In-App Review')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _completeTask,
              child: const Text('Complete a task'),
            ),
            const SizedBox(height: 16),
            const Text(
              'A request does not guarantee a visible dialog. '
              'Use a physical iOS device or a Google Play test installation.',
            ),
          ],
        ),
      ),
    ),
  );
}
