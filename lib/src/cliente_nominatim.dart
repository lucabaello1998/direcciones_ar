import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'direccion_sugerida.dart';
import 'excepciones.dart';

/// Centro de Buenos Aires, útil como punto de partida de un mapa.
const direccionesArBuenosAires = (-34.6037, -58.3816);

/// Cliente para el Nominatim público de OpenStreetMap: búsqueda de direcciones
/// (`/search`) y geocodificación inversa (`/reverse`).
///
/// Tres cosas que hace para que sea usable desde una app sin que el servicio te
/// corte el acceso:
///
/// - **Serializa las llamadas** (`intervaloMinimo`, 1,1 s por defecto): la
///   política de Nominatim es 1 request por segundo. Si dos campos piden
///   direcciones a la vez, la segunda espera su turno en vez de salir en
///   paralelo.
/// - **Cachea** en memoria resultados y reversas: tipear y borrar sobre la misma
///   dirección, o tocar dos veces el mismo punto del mapa, no vuelve a consultar.
/// - **Identifica la app** con un `User-Agent` propio, como pide la política de
///   uso (y permite que te contacten si hay un problema).
///
/// ```dart
/// final cliente = ClienteNominatim();
/// final opciones = await cliente.buscar('italia 2274 caballito');
/// print(opciones.first.direccionCorta); // Italia 2274, Caballito
/// final reversa = await cliente.reversa(-34.6109, -58.4337);
/// cliente.cerrar();
/// ```
class ClienteNominatim {
  ClienteNominatim({
    http.Client? cliente,
    this.pais = 'ar',
    this.userAgent =
        'direcciones_ar/0.1 (+https://github.com/lucabaello1998/direcciones_ar)',
    this.intervaloMinimo = const Duration(milliseconds: 1100),
    this.tiempoMaximo = const Duration(seconds: 8),
    this.cacheMaximo = 200,
    Uri? servicio,
  })  : _cliente = cliente ?? http.Client(),
        _esPropio = cliente == null,
        _servicio =
            servicio ?? Uri.parse('https://nominatim.openstreetmap.org');

  /// Código de país para acotar los resultados (`countrycodes`). `null` busca en
  /// todo el mundo.
  final String? pais;

  final String userAgent;

  /// Espera mínima entre dos requests reales.
  final Duration intervaloMinimo;

  final Duration tiempoMaximo;

  /// Cuántas búsquedas y reversas se guardan en memoria.
  final int cacheMaximo;

  final http.Client _cliente;
  final bool _esPropio;
  final Uri _servicio;

  final LinkedHashMap<String, List<DireccionSugerida>> _cacheBusquedas =
      LinkedHashMap<String, List<DireccionSugerida>>();
  final LinkedHashMap<String, DireccionSugerida?> _cacheReversas =
      LinkedHashMap<String, DireccionSugerida?>();

  Future<void> _cola = Future<void>.value();
  DateTime _ultimaLlamada = DateTime.fromMillisecondsSinceEpoch(0);

  /// Busca direcciones para [texto] y devuelve hasta [limite] resultados.
  ///
  /// Lista vacía significa "no hay coincidencias". Si el servicio no responde o
  /// devuelve algo raro, tira [ErrorDeGeocoding].
  Future<List<DireccionSugerida>> buscar(String texto, {int limite = 5}) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return const [];

    final clave = '${consulta.toLowerCase()}|$limite|$pais';
    final cacheada = _cacheBusquedas.remove(clave);
    if (cacheada != null) {
      _cacheBusquedas[clave] = cacheada; // LRU: se renueva al usarse
      return cacheada;
    }

    final uri = _servicio.replace(
      path: '/search',
      queryParameters: {
        'q': consulta,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limite',
        'accept-language': 'es',
        'dedupe': '1',
        if (pais != null) 'countrycodes': pais!,
      },
    );

    final cuerpo = await _pedir(uri);
    if (cuerpo is! List) {
      throw const ErrorDeGeocoding(
          'El buscador devolvió una respuesta inesperada.');
    }

    final resultados = cuerpo
        .whereType<Map<String, dynamic>>()
        .map(DireccionSugerida.desdeNominatim)
        .where((direccion) => direccion.esUbicable)
        .toList();

    _guardar(_cacheBusquedas, clave, resultados);
    return resultados;
  }

  /// Dirección más cercana a un punto, o `null` si el servicio no encontró
  /// ninguna. Tira [ErrorDeGeocoding] si la consulta falló.
  Future<DireccionSugerida?> reversa(double latitud, double longitud) async {
    final clave =
        '${latitud.toStringAsFixed(5)},${longitud.toStringAsFixed(5)}|$pais';
    if (_cacheReversas.containsKey(clave)) {
      final cacheada = _cacheReversas.remove(clave);
      _cacheReversas[clave] = cacheada;
      return cacheada;
    }

    final uri = _servicio.replace(
      path: '/reverse',
      queryParameters: {
        'lat': '$latitud',
        'lon': '$longitud',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
        'accept-language': 'es',
      },
    );

    final cuerpo = await _pedir(uri);
    if (cuerpo is! Map<String, dynamic>) {
      throw const ErrorDeGeocoding(
          'El buscador devolvió una respuesta inesperada.');
    }

    // Nominatim responde 200 con {"error": "Unable to geocode"} cuando el punto
    // cae en el mar o no tiene una dirección asociada.
    DireccionSugerida? resultado;
    if (cuerpo['error'] == null) {
      final direccion = DireccionSugerida.desdeNominatim(cuerpo);
      resultado = direccion.esUbicable && direccion.direccionCorta.isNotEmpty
          ? direccion
          : null;
    }

    _guardar(_cacheReversas, clave, resultado);
    return resultado;
  }

  /// Cierra el cliente HTTP si lo creó este objeto (si lo inyectaron, es de quien
  /// lo pasó).
  void cerrar() {
    if (_esPropio) _cliente.close();
  }

  Future<Object?> _pedir(Uri uri) async {
    await _esperarTurno();

    final http.Response respuesta;
    try {
      respuesta = await _cliente.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'es',
          'User-Agent': userAgent,
        },
      ).timeout(tiempoMaximo);
    } on TimeoutException catch (error) {
      throw ErrorDeGeocoding('El buscador no respondió a tiempo.',
          causa: error);
    } catch (error) {
      throw ErrorDeGeocoding('No se pudo consultar el buscador.', causa: error);
    }

    if (respuesta.statusCode != 200) {
      throw ErrorDeGeocoding(
        'El buscador respondió con un error.',
        codigoDeEstado: respuesta.statusCode,
      );
    }

    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } catch (error) {
      throw ErrorDeGeocoding('La respuesta del buscador no es JSON válido.',
          causa: error);
    }
  }

  /// Cola de a una: dos llamadas simultáneas se serializan con la espera mínima
  /// entre medio, en vez de salir juntas y comerse el rate limit.
  Future<void> _esperarTurno() {
    final turno = _cola.then((_) async {
      final desdeLaUltima = DateTime.now().difference(_ultimaLlamada);
      if (desdeLaUltima < intervaloMinimo) {
        await Future<void>.delayed(intervaloMinimo - desdeLaUltima);
      }
      _ultimaLlamada = DateTime.now();
    });

    // Un fallo de una request no puede cortar la cola de las siguientes.
    _cola = turno.catchError((Object _) {});
    return turno;
  }

  void _guardar<T>(LinkedHashMap<String, T> cache, String clave, T valor) {
    cache[clave] = valor;
    while (cache.length > cacheMaximo) {
      cache.remove(cache.keys.first);
    }
  }
}
