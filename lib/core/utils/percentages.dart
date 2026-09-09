/// Reparte [target] (100 por defecto) entre [counts] enteros con el método
/// del resto mayor (Hamilton): cada parte se redondea hacia abajo y el
/// faltante para llegar al objetivo se asigna, punto a punto, a las partes
/// con mayor resto fraccionario. Así la suma de los porcentajes devueltos
/// es SIEMPRE exactamente [target].
///
/// Si [counts] es vacío o el total es 0, devuelve una lista de ceros.
List<int> distributePercentages(List<int> counts, {int target = 100}) {
  if (counts.isEmpty) return const [];

  final total = counts.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return List<int>.filled(counts.length, 0);

  final n = counts.length;
  final result = List<int>.filled(n, 0);
  final remainders = List<double>.filled(n, 0);
  var assigned = 0;
  for (var i = 0; i < n; i++) {
    final exact = counts[i] * target / total;
    result[i] = exact.floor();
    remainders[i] = exact - result[i];
    assigned += result[i];
  }

  // En orden de resto descendente se reparte el faltante, 1 por parte.
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => remainders[b].compareTo(remainders[a]));
  var left = target - assigned;
  for (var i = 0; i < n && left > 0; i++) {
    result[order[i]]++;
    left--;
  }
  return result;
}