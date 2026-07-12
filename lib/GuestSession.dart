/// Tracks whether the current app session is browsing as a guest
/// (no Firebase account). Guests skip account/profile features and
/// scanned items are kept in memory only instead of being synced.
class GuestSession {
  GuestSession._();

  static bool isGuest = false;

  static void start() => isGuest = true;

  static void end() => isGuest = false;
}
