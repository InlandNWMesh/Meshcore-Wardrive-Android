List<int>? _parseVersion(String v) {
  final parts = v.trim().split('.');
  if (parts.length != 3) return null;
  try {
    return parts.map(int.parse).toList();
  } catch (_) {
    return null;
  }
}

/// Returns true if [current] is below [minimum].
/// Fails open (returns false) if either string is malformed.
bool isVersionBelow(String current, String minimum) {
  final cur = _parseVersion(current);
  final min = _parseVersion(minimum);
  if (cur == null || min == null) return false;
  for (int i = 0; i < 3; i++) {
    if (cur[i] < min[i]) return true;
    if (cur[i] > min[i]) return false;
  }
  return false;
}
