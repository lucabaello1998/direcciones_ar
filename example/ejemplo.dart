// Ejemplo ejecutable: dart run example/ejemplo.dart "italia 2274 caballito"
//
// Hace una búsqueda real contra Nominatim, así que necesita internet. Respeta el
// límite del servicio (una llamada cada 1,1 s).
//
// ignore_for_file: avoid_print
import 'package:direcciones_ar/direcciones_ar.dart';

Future<void> main(List<String> argumentos) async {
  final consulta = argumentos.join(' ').trim();
  if (consulta.isEmpty) {
    print('Uso: dart run example/ejemplo.dart "italia 2274 caballito"');
    return;
  }

  final cliente = ClienteNominatim(userAgent: 'direcciones_ar_ejemplo/0.1');
  try {
    final opciones = await cliente.buscar(consulta);

    if (opciones.isEmpty) {
      print('Sin resultados para "$consulta".');
      return;
    }

    print('Resultados para "$consulta":\n');
    for (final opcion in opciones) {
      print('- ${opcion.direccionCorta}');
      print('  ${opcion.detalle}');
      print('  (${opcion.latitud}, ${opcion.longitud})');
    }

    final primera = opciones.first;
    final vuelta = await cliente.reversa(primera.latitud, primera.longitud);
    print(
        '\nReversa del primer resultado: ${vuelta?.direccionCorta ?? "sin dirección"}');
  } on ErrorDeGeocoding catch (error) {
    print('No se pudo consultar el buscador: $error');
  } finally {
    cliente.cerrar();
  }
}
