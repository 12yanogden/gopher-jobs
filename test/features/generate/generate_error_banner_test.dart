import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/core/errors.dart';
import 'package:gopher_jobs/features/generate/generate_error_banner.dart';

void main() {
  testWidgets('renders JobFetchException with cause details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenerateErrorBanner(
            error: JobFetchException(
              'Could not fetch the job posting (network or CORS).',
              cause: Exception('ClientException: CORS blocked'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('generateError')), findsOneWidget);
    expect(find.textContaining('CORS'), findsWidgets);
  });
}
