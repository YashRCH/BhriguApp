double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;

  double dot = 0;
  double normA = 0;
  double normB = 0;

  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  final denominator = normA * normB;

  if (denominator == 0) return 0;

  return dot / denominator;
}
