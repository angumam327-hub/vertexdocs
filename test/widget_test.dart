import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vertexdocs/app.dart';
import 'package:vertexdocs/services/auth_service.dart';
import 'package:vertexdocs/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VertexDocs App unauthenticated shows Login screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();
    await AuthService().init(force: true);

    await tester.pumpWidget(const VertexDocsApp());
    await tester.pumpAndSettle();

    expect(find.text('VertexDocs'), findsWidgets);
    expect(find.text('Welcome Back'), findsWidgets);
    expect(
        find.text('Sign in to access your PDF Toolkit & Documents'),
        findsWidgets);
  });

  testWidgets('VertexDocs App authenticated smoke test',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'vertex_auth_is_logged_in': true,
      'vertex_auth_current_user':
          '{"uid":"test-user","name":"Test User","email":"test@example.com"}',
    });
    await StorageService().init();
    await AuthService().init(force: true);

    await tester.pumpWidget(const VertexDocsApp());
    await tester.pumpAndSettle();

    expect(find.text('VertexDocs'), findsWidgets);
    expect(find.text('Your PDFs, made simple.'), findsWidgets);
    expect(find.text('Choose a File'), findsWidgets);
  });
}
