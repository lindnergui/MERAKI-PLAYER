import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Checks the public GitHub releases endpoint without affecting app startup.
class ReleaseUpdateService {
  ReleaseUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/lindnergui/MERAKI-PLAYER/releases/latest',
  );

  final HttpClient _httpClient;

  Future<ReleaseUpdate?> findAvailableUpdate({
    required String currentVersion,
  }) async {
    try {
      final request = await _httpClient
          .getUrl(_latestReleaseUri)
          .timeout(const Duration(seconds: 8));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Meraki update checker');

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) return null;

      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      if (payload is! Map<String, dynamic>) return null;

      final tagName = payload['tag_name'] as String?;
      final releaseUrl = payload['html_url'] as String?;
      if (tagName == null || releaseUrl == null) return null;

      if (!_isVersionNewer(candidate: tagName, current: currentVersion)) {
        return null;
      }

      return ReleaseUpdate(
        version: _displayVersion(tagName),
        releaseUrl: Uri.tryParse(releaseUrl),
      );
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static bool _isVersionNewer({
    required String candidate,
    required String current,
  }) {
    final candidateParts = _versionParts(candidate);
    final currentParts = _versionParts(current);
    if (candidateParts == null || currentParts == null) return false;

    for (var index = 0; index < 3; index++) {
      if (candidateParts[index] != currentParts[index]) {
        return candidateParts[index] > currentParts[index];
      }
    }
    return false;
  }

  static List<int>? _versionParts(String value) {
    final match = RegExp(
      r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return <int>[
      int.parse(match.group(1)!),
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
    ];
  }

  static String _displayVersion(String version) =>
      version.startsWith('v') ? version.substring(1) : version;
}

class ReleaseUpdate {
  const ReleaseUpdate({required this.version, required this.releaseUrl});

  final String version;
  final Uri? releaseUrl;
}
