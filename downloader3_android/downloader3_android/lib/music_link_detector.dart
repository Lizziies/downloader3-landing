// Detects Spotify/Apple Music/Amazon Music links pasted into the download
// URL field and builds a YouTube search query from resolved metadata so
// the existing yt-dlp pipeline can be reused (ytsearch1:<query>).

final RegExp spotifyLinkRe = RegExp(
  r'^(https?://)?open\.spotify\.com/(intl-\w+/)?(track|playlist|album)/',
  caseSensitive: false,
);

final RegExp appleMusicLinkRe = RegExp(
  r'music\.apple\.com',
  caseSensitive: false,
);

final RegExp amazonMusicLinkRe = RegExp(
  r'music\.amazon\.\w+',
  caseSensitive: false,
);

/// True if [url] points at a Spotify, Apple Music or Amazon Music link that
/// should be resolved via the backend's /api/music-lookup endpoint instead
/// of the normal platform-specific download pipeline.
bool isMusicLink(String url) {
  final u = url.trim();
  if (u.isEmpty) return false;
  return spotifyLinkRe.hasMatch(u) ||
      appleMusicLinkRe.hasMatch(u) ||
      amazonMusicLinkRe.hasMatch(u);
}

/// Builds a YouTube search query string from resolved music metadata,
/// e.g. 'Shape of You Ed Sheeran'.
String buildYtSearchQuery(String? title, String? artist) =>
    artist == null || artist.isEmpty ? (title ?? '') : "$title $artist";
