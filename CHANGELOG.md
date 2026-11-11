# Changelog

## 0.2.0

- `direccionCorta` ahora prefiere el barrio antes que la localidad. En CABA la
  localidad es "Ciudad Autónoma de Buenos Aires" para las 15 comunas, así que
  las sugerencias decían "Rivadavia 5000, Ciudad Autónoma de Buenos Aires" —
  indistinguible de cualquier otro punto de la ciudad. Ahora dicen
  "Avenida Rivadavia 5000, Caballito", que es lo que ya prometía la
  documentación. Sin barrio en la respuesta, sigue usando la localidad.
- README: cómo desarrollarlo, cómo publicarlo en pub.dev y qué significan las
  respuestas vacías.

## 0.1.0

- Primera versión publicada: búsqueda y geocodificación inversa de direcciones
  argentinas con Nominatim, caché, límite de requests y parseo en calle, altura,
  barrio y localidad.
