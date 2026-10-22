import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:direcciones_ar/direcciones_ar.dart';

const _resultado = <String, dynamic>{
  'lat': '-34.6109810',
  'lon': '-58.4337910',
  'display_name':
      'Italia 2274, Caballito, Ciudad Autónoma de Buenos Aires, Argentina',
  'address': {
    'road': 'Italia',
    'house_number': '2274',
    'suburb': 'Caballito',
    'city': 'Ciudad Autónoma de Buenos Aires',
  },
};

const _reversa = <String, dynamic>{
  'lat': '-34.610981',
  'lon': '-58.433791',
  'display_name': 'Otamendi 500, Caballito, Argentina',
  'address': {'road': 'Otamendi', 'house_number': '500', 'suburb': 'Caballito'},
};

http.Response _json(Object cuerpo, {int estado = 200}) => http.Response(
      jsonEncode(cuerpo),
      estado,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('buscar pega en /search con país, idioma y límite', () async {
    String? ruta;
    Map<String, String>? parametros;

    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((request) async {
        ruta = request.url.path;
        parametros = request.url.queryParameters;
        expect(request.headers['User-Agent'], contains('direcciones_ar'));
        return _json([_resultado]);
      }),
    );

    final resultados = await cliente.buscar('  italia 2274  ');

    expect(ruta, '/search');
    expect(parametros?['q'], 'italia 2274');
    expect(parametros?['countrycodes'], 'ar');
    expect(parametros?['limit'], '5');
    expect(resultados, hasLength(1));
    expect(resultados.single.direccionCorta,
        'Italia 2274, Ciudad Autónoma de Buenos Aires');
  });

  test('texto vacío no hace ninguna request', () async {
    var llamadas = 0;
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((_) async {
        llamadas++;
        return _json(const []);
      }),
    );

    expect(await cliente.buscar('   '), isEmpty);
    expect(llamadas, 0);
  });

  test('cachea búsquedas y reversas', () async {
    var llamadas = 0;
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((request) async {
        llamadas++;
        return request.url.path == '/search'
            ? _json([_resultado])
            : _json(_reversa);
      }),
    );

    await cliente.buscar('italia 2274');
    await cliente.buscar('ITALIA 2274');
    await cliente.reversa(-34.610981, -58.433791);
    await cliente.reversa(-34.610981, -58.433791);

    expect(llamadas, 2);
  });

  test('descarta resultados sin coordenadas', () async {
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((_) async => _json([
            {'display_name': 'Sin lat ni lon'},
            _resultado,
          ])),
    );

    final resultados = await cliente.buscar('italia 2274');

    expect(resultados, hasLength(1));
    expect(resultados.single.calle, 'Italia');
  });

  test('espacia las llamadas simultáneas según intervaloMinimo', () async {
    final inicios = <DateTime>[];

    final cliente = ClienteNominatim(
      intervaloMinimo: const Duration(milliseconds: 200),
      cliente: MockClient((request) async {
        inicios.add(DateTime.now());
        return request.url.path == '/search'
            ? _json([_resultado])
            : _json(_reversa);
      }),
    );

    await Future.wait([
      cliente.buscar('italia 2274'),
      cliente.reversa(-34.610981, -58.433791),
      cliente.buscar('otamendi 500'),
    ]);

    expect(inicios, hasLength(3));
    for (var i = 1; i < inicios.length; i++) {
      final separacion = inicios[i].difference(inicios[i - 1]);
      expect(
        separacion.inMilliseconds,
        greaterThanOrEqualTo(150),
        reason: 'la llamada $i salió $separacion después de la anterior',
      );
    }
  });

  test('un error HTTP tira ErrorDeGeocoding con el código', () async {
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente:
          MockClient((_) async => _json(const {'error': 'boom'}, estado: 429)),
    );

    expect(
      () => cliente.buscar('italia 2274'),
      throwsA(isA<ErrorDeGeocoding>()
          .having((e) => e.codigoDeEstado, 'codigoDeEstado', 429)),
    );
  });

  test('la reversa devuelve null cuando el punto no tiene dirección', () async {
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente:
          MockClient((_) async => _json(const {'error': 'Unable to geocode'})),
    );

    expect(await cliente.reversa(0, 0), isNull);
  });

  test('un JSON inválido tira ErrorDeGeocoding', () async {
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((_) async => http.Response('no es json', 200)),
    );

    expect(
        () => cliente.buscar('italia 2274'), throwsA(isA<ErrorDeGeocoding>()));
  });

  test('un fallo no corta la cola de las llamadas siguientes', () async {
    var llamadas = 0;
    final cliente = ClienteNominatim(
      intervaloMinimo: Duration.zero,
      cliente: MockClient((request) async {
        llamadas++;
        if (llamadas == 1) return http.Response('error', 500);
        return request.url.path == '/search'
            ? _json([_resultado])
            : _json(_reversa);
      }),
    );

    await expectLater(
        cliente.buscar('italia 2274'), throwsA(isA<ErrorDeGeocoding>()));
    expect(await cliente.buscar('otamendi 500'), hasLength(1));
  });
}
