// Test smoke básico: la app arranca sin crashear.
// Como MishkaApp abre SQLite y usa Riverpod, no probamos flows aquí — para eso
// harían falta mocks. Este test solo garantiza que el árbol de widgets se monta.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mishka_gdi_app/main.dart';

void main() {
  testWidgets('MishkaApp se monta sin crashear', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MishkaApp()));
    // La primera pantalla es un MaterialApp (router) — con eso alcanza para
    // validar que la construcción no lanza excepciones.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
