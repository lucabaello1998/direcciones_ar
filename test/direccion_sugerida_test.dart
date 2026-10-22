import 'package:test/test.dart';

import 'package:direcciones_ar/direcciones_ar.dart';

/// Respuestas reales de Nominatim (recortadas) para no inventar el formato:
/// `GET /search?q=italia+2274&countrycodes=ar` y `GET /reverse?lat&lon`.
const _busqueda = <String, dynamic>{
  'place_id': 123456,
  'lat': '-34.6109810',
  'lon': '-58.4337910',
  'display_name':
      'Italia 2274, Caballito, Comuna 6, Ciudad Autónoma de Buenos Aires, 1424, Argentina',
  'address': {
    'road': 'Italia',
    'house_number': '2274',
    'suburb': 'Caballito',
    'city_district': 'Comuna 6',
    'city': 'Ciudad Autónoma de Buenos Aires',
    'state': 'Ciudad Autónoma de Buenos Aires',
    'postcode': '1424',
    'country': 'Argentina',
  },
};

const _reversa = <String, dynamic>{
  'lat': '-34.610981',
  'lon': '-58.433791',
  'display_name':
      'Otamendi 500, Caballito, Comuna 6, Ciudad Autónoma de Buenos Aires, 1424, Argentina',
  'address': {
    'road': 'Otamendi',
    'house_number': '500',
    'suburb': 'Caballito',
    'city': 'Ciudad Autónoma de Buenos Aires',
    'state': 'Ciudad Autónoma de Buenos Aires',
  },
};

void main() {
  group('DireccionSugerida', () {
    test('desarma una búsqueda en calle, altura, barrio y localidad', () {
      final direccion = DireccionSugerida.desdeNominatim(_busqueda);

      expect(direccion.latitud, closeTo(-34.610981, 0.000001));
      expect(direccion.longitud, closeTo(-58.433791, 0.000001));
      expect(direccion.calle, 'Italia');
      expect(direccion.numero, '2274');
      expect(direccion.barrio, 'Caballito');
      expect(direccion.localidad, 'Ciudad Autónoma de Buenos Aires');
      expect(direccion.codigoPostal, '1424');
      expect(direccion.calleYAltura, 'Italia 2274');
      expect(direccion.direccionCorta,
          'Italia 2274, Ciudad Autónoma de Buenos Aires');
      expect(direccion.esUbicable, isTrue);
    });

    test('usa la localidad cuando no hay barrio', () {
      final direccion = DireccionSugerida.desdeNominatim({
        'lat': '-31.420',
        'lon': '-64.190',
        'display_name': 'Avenida Colón 100, Córdoba, Argentina',
        'address': {
          'road': 'Avenida Colón',
          'house_number': '100',
          'city': 'Córdoba'
        },
      });

      expect(direccion.direccionCorta, 'Avenida Colón 100, Córdoba');
    });

    test('sin calle cae al primer tramo del display_name', () {
      final direccion = DireccionSugerida.desdeNominatim({
        'lat': '-34.6',
        'lon': '-58.4',
        'display_name': 'Plaza Italia, Buenos Aires, Argentina',
        'address': {'suburb': 'Recoleta'},
      });

      expect(direccion.direccionCorta, 'Plaza Italia, Recoleta');
    });

    test('no repite la localidad si ya está en el nombre de la vía', () {
      final direccion = DireccionSugerida.desdeNominatim({
        'lat': '-34.6',
        'lon': '-58.4',
        'display_name': 'Caballito 100, Caballito',
        'address': {
          'road': 'Caballito',
          'house_number': '100',
          'suburb': 'Caballito'
        },
      });

      expect(direccion.direccionCorta, 'Caballito 100');
    });

    test('detalle no repite provincia y localidad cuando son la misma', () {
      final direccion = DireccionSugerida.desdeNominatim(_busqueda);

      expect(
        direccion.detalle,
        'Caballito, Ciudad Autónoma de Buenos Aires, 1424, Argentina',
      );
    });

    test('parsea la respuesta inversa', () {
      final direccion = DireccionSugerida.desdeNominatim(_reversa);

      expect(direccion.calleYAltura, 'Otamendi 500');
      expect(direccion.direccionCorta,
          'Otamendi 500, Ciudad Autónoma de Buenos Aires');
    });

    test('sin coordenadas no es ubicable', () {
      final direccion =
          DireccionSugerida.desdeNominatim({'display_name': 'Nada'});

      expect(direccion.latitud, 0);
      expect(direccion.esUbicable, isFalse);
    });

    test('acepta coordenadas numéricas además de strings', () {
      final direccion = DireccionSugerida.desdeNominatim({
        'lat': -34.610981,
        'lon': -58.433791,
        'display_name': 'Italia 2274',
        'address': {'road': 'Italia', 'house_number': '2274'},
      });

      expect(direccion.latitud, -34.610981);
      expect(direccion.esUbicable, isTrue);
    });
  });
}
