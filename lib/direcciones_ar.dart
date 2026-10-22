/// Autocompletado y geocodificación inversa de direcciones argentinas,
/// usando el servicio público de Nominatim (OpenStreetMap) sin API key.
library;

export 'src/cliente_nominatim.dart'
    show ClienteNominatim, direccionesArBuenosAires;
export 'src/direccion_sugerida.dart' show DireccionSugerida;
export 'src/excepciones.dart' show ErrorDeGeocoding;
