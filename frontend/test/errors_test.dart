import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/errors.dart';
import 'package:grpc/grpc.dart';

void main() {
  test('traduce los códigos del flujo principal', () {
    expect(friendlyError(const GrpcError.invalidArgument()), contains('vacío'));
    expect(friendlyError(const GrpcError.permissionDenied()), 'No eres miembro de este canal');
    expect(friendlyError(const GrpcError.unavailable()), contains('no disponible'));
    expect(friendlyError(const GrpcError.deadlineExceeded()), contains('no disponible'));
    expect(friendlyError(const GrpcError.alreadyExists()), 'Ese nombre ya existe');
  });

  test('errores que no son gRPC', () {
    expect(friendlyError(Exception('x')), startsWith('Error inesperado'));
  });
}
