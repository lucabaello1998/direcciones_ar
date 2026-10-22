# direcciones_ar

Autocompletado y geocodificación inversa de direcciones argentinas con
[Nominatim](https://nominatim.openstreetmap.org/) (OpenStreetMap). Sin API key.

- **Buscar**: `italia 2274 caballito` → lista de direcciones con lat/lon.
- **Revertir**: tocás un punto del mapa → la dirección más cercana.
- **Cachea** y **espacia** las llamadas para respetar la política de uso del
  servicio público (1 request por segundo).
- **Distingue** "no hay resultados" (lista vacía) de "el servicio falló"
  (`ErrorDeGeocoding`), que es lo que permite decir "revisá tu conexión" en vez
  de "esa dirección no existe".

## Instalar

Todavía no está publicado en pub.dev. Como dependencia de git:

```yaml
dependencies:
  direcciones_ar:
    git:
      url: https://github.com/lucabaello1998/direcciones_ar.git
```

## Usar

```dart
import 'package:direcciones_ar/direcciones_ar.dart';

final cliente = ClienteNominatim(); // userAgent propio incluido

// Autocompletado
final opciones = await cliente.buscar('italia 2274 caballito');
for (final opcion in opciones) {
  print('${opcion.direccionCorta} · ${opcion.detalle}');
  // Italia 2274, Caballito · Caballito, Ciudad Autónoma de Buenos Aires, 1424, Argentina
}

// Geocodificación inversa
final direccion = await cliente.reversa(-34.610981, -58.433791);
print(direccion?.direccionCorta); // Otamendi 500, Caballito

cliente.cerrar();
```

### En Flutter

El cliente es independiente de la UI: guardalo en un provider y usalo desde el
campo de texto. Para el debounce del tipeo, `Timer` de 500-700 ms alcanza; de más
no aporta porque las llamadas ya están espaciadas.

```dart
final clienteGeocodingProvider = Provider<ClienteNominatim>((ref) {
  final cliente = ClienteNominatim();
  ref.onDispose(cliente.cerrar);
  return cliente;
});
```

## Qué devuelve

`DireccionSugerida` trae los campos ya separados, que es la parte que suele
faltar en otros clientes:

| Campo | Ejemplo |
|---|---|
| `calle` / `numero` | `Italia` / `2274` |
| `barrio` | `Caballito` |
| `localidad` | `Ciudad Autónoma de Buenos Aires` |
| `provincia` / `codigoPostal` / `pais` | `Buenos Aires` / `1424` / `Argentina` |
| `calleYAltura` | `Italia 2274` |
| `direccionCorta` | `Italia 2274, Caballito` |
| `detalle` | `Caballito, Ciudad Autónoma de Buenos Aires, 1424, Argentina` |
| `etiqueta` | el `display_name` original |

`esUbicable` es `false` cuando el resultado no trae coordenadas, así se puede
descartar antes de mostrarlo.

## Configuración

```dart
ClienteNominatim(
  pais: 'ar',                                  // null para buscar en todo el mundo
  intervaloMinimo: const Duration(milliseconds: 1100),
  tiempoMaximo: const Duration(seconds: 8),
  cacheMaximo: 200,
  userAgent: 'mi_app/1.0 (+https://mi-app.com)',
);
```

## Uso responsable del servicio público

Nominatim es gratis y lo mantiene la comunidad. Si vas a producción con volumen:

1. Poné un `User-Agent` que identifique tu app y un contacto.
2. No bajes de 1 request por segundo (el default ya lo respeta).
3. Cacheá lo que puedas.
4. Si necesitás más volumen, usá una instancia propia o un proveedor pago
   (Google Places, Mapbox, Photon autohospedado).

Ver la [política de uso](https://operations.osmfoundation.org/policies/nominatim/).

## Tests

```bash
dart pub get
dart test
```

Los tests usan `MockClient` de `package:http`: no pegan al servicio real.

## Licencia

MIT.
