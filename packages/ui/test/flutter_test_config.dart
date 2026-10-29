import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(
      Duration(
        seconds: int.fromEnvironment(
          'NEX_TEST_TIMEOUT_SECONDS',
          defaultValue: 120,
        ),
      ),
    );
  }
  await testMain();
}
