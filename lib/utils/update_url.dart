/// Where contributors get a new build.
///
/// The repo is public, so release assets download anonymously — no GitHub
/// account, no auth. That matters: an update prompt is worthless if the link
/// behind it asks for a login.
const String defaultReleasesUrl =
    'https://github.com/SpokaneMesh/Meshcore-Wardrive-Android/releases/latest';

/// Resolve the download link, preferring the server's value.
///
/// Server-supplied so the download location can move without shipping an APK —
/// which is exactly the situation this exists for, since the whole point is
/// getting people off the version they already have.
///
/// Only https is accepted. The server validates this too, but the value ends up
/// in `launchUrl(..., LaunchMode.externalApplication)` on every contributor's
/// phone, so a bad scheme is worth refusing at the point of use rather than
/// trusting a check that happened somewhere else. Anything suspect falls back
/// to the built-in URL instead of failing closed — a prompt with no working
/// link is worse than a prompt pointing at the default.
String resolveUpdateUrl(String? serverUrl) {
  if (serverUrl == null || serverUrl.isEmpty) return defaultReleasesUrl;
  final uri = Uri.tryParse(serverUrl);
  // `hasAuthority` is true for "https:///path" — the authority is present but
  // empty — so the host has to be checked separately or a hostless URL gets
  // handed to the launcher and simply fails.
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return defaultReleasesUrl;
  }
  return serverUrl;
}
