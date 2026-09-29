import 'package:grpc/grpc.dart';

/// Traduce los códigos gRPC que devuelve el backend a mensajes para el usuario.
String friendlyError(Object error) {
  if (error is! GrpcError) return 'Error inesperado: $error';
  switch (error.code) {
    case StatusCode.invalidArgument:
      return 'Datos inválidos: el mensaje está vacío o es muy largo';
    case StatusCode.permissionDenied:
      return 'No eres miembro de este canal';
    case StatusCode.unavailable:
    case StatusCode.deadlineExceeded:
      return 'Servicio no disponible, intenta de nuevo';
    case StatusCode.alreadyExists:
      return 'Ese nombre ya existe';
    case StatusCode.notFound:
      return 'No existe';
    default:
      return 'Error ${error.codeName}: ${error.message ?? ''}';
  }
}
