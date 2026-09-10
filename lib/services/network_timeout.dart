import 'dart:async';

/// Tiempo máximo para entregar una petición de red contra Supabase en el
/// arranque o en acciones sensibles (login, amigos, cargar un amigo).
///
/// Sin este techo, si la red se cae o se cuelga el handshake TLS, los
/// `await` quedan pendientes para siempre: la app se ve congelada (spinner
/// infinito en el arranque, botones en "cargando" eterno). Con el timeout,
/// los providers entran por su camino de error (pantalla con reintento) y
/// nunca se pierde el control de la UI.
const Duration kSupabaseRequestTimeout = Duration(seconds: 8);

/// Ejecuta [action] con un tope de [kSupabaseRequestTimeout]. Si tarda más,
/// lanza un [TimeoutException] (que el call-site convierte al error
/// apropiado, p. ej. [SyncException]). El resultado tardío de la petición
/// original se descarta de forma segura.
Future<T> withSupabaseTimeout<T>(Future<T> Function() action) =>
    action().timeout(kSupabaseRequestTimeout);