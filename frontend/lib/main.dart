import 'package:flutter/material.dart';

import 'src/features/users/users_screen.dart';
import 'src/grpc/clients.dart';

void main() {
  runApp(ChatApp(clients: ChatClients.create()));
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, required this.clients});

  final ChatClients clients;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat por canales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14213D)),
        useMaterial3: true,
      ),
      home: UsersScreen(clients: clients),
    );
  }
}
