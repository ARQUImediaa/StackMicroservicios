import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../generated/community/v1/community.pbgrpc.dart';
import '../generated/messaging/v1/messaging.pbgrpc.dart';

/// Conexión única hacia Envoy (ADR-05): la app no conoce los servicios internos,
/// solo `host:8080`. gRPC nativo sobre HTTP/2, sin grpc-web (ADR-08).
class ChatClients {
  ChatClients._(this._channel)
      : community = CommunityServiceClient(_channel),
        messaging = MessagingServiceClient(_channel);

  final ClientChannel _channel;
  final CommunityServiceClient community;
  final MessagingServiceClient messaging;

  static const int port = 8080;

  /// Host según la plataforma. Se puede forzar con `--dart-define=HOST=192.168.x.x`
  /// (por ejemplo, para un celular físico en la misma red Wi-Fi que el portátil).
  static String resolveHost() {
    const override = String.fromEnvironment('HOST');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2'; // emulador → portátil
    return 'localhost'; // escritorio Windows en el mismo portátil
  }

  factory ChatClients.create() {
    final host = resolveHost();
    debugPrint('[chat] conectando a $host:$port');
    final channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    return ChatClients._(channel);
  }

  Future<void> close() => _channel.shutdown();
}
