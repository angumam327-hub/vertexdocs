import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vertexdocs/app.dart';
import 'package:vertexdocs/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VertexDocs App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().init();

    await tester.pumpWidget(const VertexDocsApp());
    await tester.pumpAndSettle();

    expect(find.text('VertexDocs'), findsWidgets);
    expect(find.text('Your PDFs, made simple.'), findsWidgets);
    expect(find.text('Choose a File'), findsWidgets);
  });
}
