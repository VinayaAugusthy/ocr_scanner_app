/// Collapses whitespace and lowercases so two OCR runs can be compared for
/// duplicate detection (card and passbook scanners).
String normalizeOcrForDuplicateComparison(String raw) {
  return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
