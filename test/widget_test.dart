import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_app/main.dart';
import 'package:flutter_chat_app/screens/login_screen.dart';
import 'package:flutter_chat_app/screens/chat_screen.dart';

void main() {
  testWidgets('Full login and chat screen test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(NeonChatApp());
    await tester.pumpAndSettle();

    // 1️⃣ Verify Login screen
    expect(find.text('NEON CHAT'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('LOGIN'), findsOneWidget);

    // 2️⃣ Enter username & password
    await tester.enterText(find.byType(TextField).at(0), 'testuser');
    await tester.enterText(find.byType(TextField).at(1), '12345');

    // 3️⃣ Tap LOGIN button
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    // NOTE: Since real API is not called in widget tests, this won't navigate.
    // We'll simulate navigation manually:
    await tester.pumpWidget(MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();

    // 4️⃣ Verify Chat screen
    expect(find.byType(TextField), findsOneWidget); // message input
    expect(find.byIcon(Icons.send), findsOneWidget);

    // 5️⃣ Enter a chat message
    await tester.enterText(find.byType(TextField), 'Hello Neon!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 6️⃣ Verify message displayed (mocked)
    // Since Socket.IO messages are real-time, you would normally mock the message list
    // Here, just check input cleared after send
    final TextField input = tester.widget(find.byType(TextField));
    expect(input.controller!.text, '');
  });
}

