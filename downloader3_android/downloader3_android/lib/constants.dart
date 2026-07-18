/// 👑 1:1 aus app.py übernommen (OWNER_EMAILS) — NICHT geraten, dort
/// nachgelesen. Nur diese beiden Adressen bekommen den Admin-Menüpunkt
/// überhaupt angezeigt; die eigentliche Berechtigung wird trotzdem
/// zusätzlich (und ausschließlich) serverseitig über /api/verify-owner
/// geprüft, dieser Client-Check ist nur fürs Ausblenden im Menü.
const Set<String> kOwnerEmails = {
  'felixwerther1@gmail.com',
  'lisa.werther@proton.me',
};
