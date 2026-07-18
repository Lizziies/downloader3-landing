import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🚀 Spiegelt exakt den Update-Mechanismus der Desktop-App
/// (check_for_updates() in main.py): fragt das "Latest Release" des
/// GLEICHEN GitHub-Repos (Lizziies/downloader3-landing) über die
/// öffentliche GitHub-API ab. Unterschied zum Desktop: dort wird nach
/// einer .zip gesucht, hier nach einer .apk — beide können im selben
/// Release hängen (die .github/workflows/build-apk.yml in diesem
/// Projekt hängt die .apk automatisch an, sobald ein Versions-Tag
/// gepusht wird). So bekommt "weltweit" jede installierte App-Version
/// automatisch mit, sobald ein neues Release draußen ist — exakt wie
/// am Desktop gewünscht.
const String kGithubReleaseRepo = 'Lizziies/downloader3-landing';

class UpdateInfo {
  final String version;
  final String htmlUrl;
  final String? apkUrl;
  UpdateInfo(this.version, this.htmlUrl, this.apkUrl);
}

List<int> _verTuple(String v) {
  final matches = RegExp(r'\d+').allMatches(v).map((m) => int.parse(m[0]!));
  final list = matches.take(3).toList();
  while (list.length < 3) {
    list.add(0);
  }
  return list;
}

bool isNewer(String latest, String current) {
  final a = _verTuple(latest);
  final b = _verTuple(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
  try {
    final r = await http.get(
      Uri.parse('https://api.github.com/repos/$kGithubReleaseRepo/releases/latest'),
      headers: {
        'User-Agent': 'Downloader3-Android/$currentVersion',
        'Accept': 'application/vnd.github+json',
      },
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString();
    final latest = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final htmlUrl = (data['html_url'] ?? '').toString();
    String? apkUrl;
    for (final asset in (data['assets'] as List? ?? [])) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    if (latest.isEmpty) return null;
    if (isNewer(latest, currentVersion)) {
      return UpdateInfo(latest, htmlUrl, apkUrl);
    }
    return null;
  } catch (_) {
    return null;
  }
}
