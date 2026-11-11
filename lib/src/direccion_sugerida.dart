/// Una dirección devuelta por Nominatim, ya desarmada en las partes que se usan
/// en Argentina: calle, altura, barrio y localidad.
///
/// `direccionCorta` es lo que conviene mostrar en un listado ("Italia 2274,
/// Caballito") y `etiqueta` la dirección completa que devuelve el servicio.
class DireccionSugerida {
  const DireccionSugerida({
    required this.latitud,
    required this.longitud,
    required this.etiqueta,
    this.calle,
    this.numero,
    this.barrio,
    this.localidad,
    this.provincia,
    this.codigoPostal,
    this.pais,
  });

  /// Arma una [DireccionSugerida] desde un objeto de `/search` o `/reverse`.
  ///
  /// No tira excepción con un JSON raro: deja los campos en `null` y
  /// [esUbicable] queda en `false`, que es lo que usa el cliente para descartar
  /// resultados sin coordenadas.
  factory DireccionSugerida.desdeNominatim(Map<String, dynamic> json) {
    final direccion = json['address'];
    final partes = direccion is Map ? direccion : const <String, dynamic>{};

    return DireccionSugerida(
      latitud: _numero(json['lat']) ?? 0,
      longitud: _numero(json['lon']) ?? 0,
      etiqueta: _texto(json['display_name']) ?? '',
      calle: _texto(partes['road']) ??
          _texto(partes['pedestrian']) ??
          _texto(partes['footway']) ??
          _texto(partes['residential']) ??
          _texto(partes['path']),
      numero: _texto(partes['house_number']),
      barrio: _texto(partes['suburb']) ??
          _texto(partes['neighbourhood']) ??
          _texto(partes['quarter']) ??
          _texto(partes['city_district']),
      localidad: _texto(partes['city']) ??
          _texto(partes['town']) ??
          _texto(partes['village']) ??
          _texto(partes['municipality']) ??
          _texto(partes['state']),
      provincia: _texto(partes['state']),
      codigoPostal: _texto(partes['postcode']),
      pais: _texto(partes['country']),
    );
  }

  final double latitud;
  final double longitud;

  /// La dirección completa tal como la devuelve Nominatim.
  final String etiqueta;

  final String? calle;
  final String? numero;
  final String? barrio;
  final String? localidad;
  final String? provincia;
  final String? codigoPostal;
  final String? pais;

  /// `true` si tiene coordenadas y algo para mostrar: sirve para descartar
  /// resultados incompletos antes de ofrecerlos en la UI.
  bool get esUbicable =>
      latitud != 0 &&
      longitud != 0 &&
      (etiqueta.isNotEmpty || (calle ?? '').isNotEmpty);

  /// "Italia 2274" (o sólo "Italia" si no hay altura).
  String get calleYAltura {
    final via = calle?.trim() ?? '';
    final altura = numero?.trim() ?? '';
    if (via.isEmpty) return '';
    return altura.isEmpty ? via : '$via $altura';
  }

  /// Lo que se pone en el campo de texto: "Italia 2274, Caballito".
  ///
  /// Si el servicio no devolvió la calle, cae al primer tramo de [etiqueta]. No
  /// repite la localidad cuando ya está en el nombre de la vía.
  ///
  /// El barrio va antes que la localidad a propósito: en CABA la localidad es
  /// "Ciudad Autónoma de Buenos Aires" para las 15 comunas, así que mostrarla no
  /// distingue nada ("Rivadavia 5000, Ciudad Autónoma de Buenos Aires" podría ser
  /// cualquier punto de la ciudad). El barrio sí. La localidad queda para cuando
  /// el resultado no trae barrio.
  String get direccionCorta {
    final via = calleYAltura.isNotEmpty ? calleYAltura : _primerTramo(etiqueta);
    final lugar = (barrio ?? localidad)?.trim() ?? '';
    final partes = <String>[
      if (via.isNotEmpty) via,
      if (lugar.isNotEmpty && !via.toLowerCase().contains(lugar.toLowerCase()))
        lugar,
    ];
    return partes.join(', ');
  }

  /// Barrio, localidad, provincia y código postal, sin repetir, para el subtítulo
  /// de una sugerencia.
  String get detalle {
    final vistos = <String>{};
    final partes = <String>[];
    for (final valor in [barrio, localidad, provincia, codigoPostal, pais]) {
      final limpio = valor?.trim() ?? '';
      if (limpio.isEmpty) continue;
      if (!vistos.add(limpio.toLowerCase())) continue;
      partes.add(limpio);
    }
    return partes.join(', ');
  }

  @override
  String toString() => direccionCorta.isEmpty ? etiqueta : direccionCorta;

  static String _primerTramo(String texto) => texto.split(',').first.trim();

  static String? _texto(Object? valor) {
    if (valor is! String) return null;
    final limpio = valor.trim();
    return limpio.isEmpty ? null : limpio;
  }

  static double? _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}
