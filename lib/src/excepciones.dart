/// Error del servicio de geocodificación (sin red, timeout, error del servidor
/// o una respuesta que no se puede interpretar).
///
/// Se distingue de "no hay resultados": una búsqueda exitosa sin coincidencias
/// devuelve una lista vacía. Este error existe para que la UI pueda decir
/// "no pudimos buscar, revisá tu conexión" en vez de "esa dirección no existe".
class ErrorDeGeocoding implements Exception {
  const ErrorDeGeocoding(this.mensaje, {this.codigoDeEstado, this.causa});

  final String mensaje;

  /// Código HTTP si el error vino del servidor.
  final int? codigoDeEstado;

  /// Excepción original (por ejemplo, un `SocketException`).
  final Object? causa;

  @override
  String toString() {
    final estado = codigoDeEstado == null ? '' : ' (HTTP $codigoDeEstado)';
    return 'ErrorDeGeocoding$estado: $mensaje';
  }
}
