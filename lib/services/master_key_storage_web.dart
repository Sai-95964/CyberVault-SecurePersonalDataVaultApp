import 'dart:html' as html;

class MasterKeyStorage {
  static const _key = 'cybervault_master_key';

  static void save(String base64) {
    try {
      html.window.sessionStorage[_key] = base64;
    } catch (_) {}
  }

  static String? load() {
    try {
      return html.window.sessionStorage[_key];
    } catch (_) {
      return null;
    }
  }

  static void remove() {
    try {
      html.window.sessionStorage.remove(_key);
    } catch (_) {}
  }
}
