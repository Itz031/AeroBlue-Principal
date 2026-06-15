// lib/backend/servicios/excepciones_app.dart
//
// Excepciones personalizadas de AeroBlue.
// Permiten distinguir el tipo de fallo (sin conexión, tiempo agotado,
// error del servidor, datos inválidos, etc.) para mostrar al usuario
// un mensaje claro y útil en lugar de un error genérico.

/// Error base de la aplicación. Todas las excepciones propias de
/// AeroBlue heredan de esta clase para poder atraparlas en conjunto.
abstract class AeroBlueException implements Exception {
  final String mensaje;
  const AeroBlueException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// No hay conexión a internet o no se pudo alcanzar el servidor.
class SinConexionException extends AeroBlueException {
  const SinConexionException([
    String mensaje = 'Sin conexión a internet. Revisa tu red e inténtalo de nuevo.',
  ]) : super(mensaje);
}

/// La petición tardó demasiado en responder.
class TiempoAgotadoException extends AeroBlueException {
  const TiempoAgotadoException([
    String mensaje = 'El servidor tardó demasiado en responder. Inténtalo más tarde.',
  ]) : super(mensaje);
}

/// El servidor respondió con un error (4xx o 5xx).
class ServidorException extends AeroBlueException {
  final int codigoEstado;
  ServidorException(this.codigoEstado)
      : super('El servicio de AeroBlue no está disponible (código $codigoEstado).');
}

/// La respuesta del servidor no tiene el formato esperado.
class FormatoInvalidoException extends AeroBlueException {
  const FormatoInvalidoException([
    String mensaje = 'No se pudo interpretar la información recibida del servidor.',
  ]) : super(mensaje);
}

/// Error al leer o escribir en la base de datos local del dispositivo.
class BaseDatosException extends AeroBlueException {
  const BaseDatosException([
    String mensaje = 'No se pudo acceder a la información guardada en el dispositivo.',
  ]) : super(mensaje);
}
