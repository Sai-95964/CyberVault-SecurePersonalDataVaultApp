// Stub storage for non-web platforms. No-op implementations.
class MasterKeyStorage {
  static void save(String base64) {}
  static String? load() => null;
  static void remove() {}
}
