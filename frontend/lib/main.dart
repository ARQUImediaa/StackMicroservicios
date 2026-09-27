import 'package:flutter/material.dart';
import 'package:grpc/grpc_or_grpcweb.dart';
import 'pb/service.pbgrpc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microservicios Flutter + Go',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  late PingServiceClient _client;

  @override
  void initState() {
    super.initState();
    // Configurar canal gRPC hacia el backend Go
    final channel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: 'localhost',
      port: 50051,
      transportSecure: false,
    );
    _client = PingServiceClient(channel);
  }

  Future<void> _sendPing() async {
    try {
      final response = await _client.ping(
        PingRequest()..message = _controller.text,
      );
      setState(() {
        _response = response.reply;
      });
    } catch (e) {
      setState(() {
        _response = 'Error de conexión: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente gRPC Flutter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Escribe un mensaje para Go',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendPing,
              child: const Text('Enviar mensaje via gRPC'),
            ),
            const SizedBox(height: 32),
            Text(
              _response,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}