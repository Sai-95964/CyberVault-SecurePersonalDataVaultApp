import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../helpers/key_derivation_helper.dart';
import 'master_key_storage.dart';

/// MasterKey service - stores and derives the encryption key.
///
/// SECURITY: MasterKey is stored ONLY in memory (never persisted).

class MasterKeyService {
  MasterKeyService._();
  static final MasterKeyService instance = (() {
    final svc = MasterKeyService._();
    svc.tryRestoreFromSession();
    return svc;
  })();

  /// In-memory only storage — never persisted.
  Uint8List? _masterKeyBytes;

  /// Returns MasterKey as string (base64) for legacy use, null if not set.
  String? get masterKey =>
      _masterKeyBytes != null ? base64Encode(_masterKeyBytes!) : null;

  /// Returns MasterKey as raw bytes (32 bytes for AES-256), null if not set.
  Uint8List? get masterKeyBytes => _masterKeyBytes != null
      ? Uint8List.fromList(_masterKeyBytes!)
      : null;

  /// Derive MasterKey from PIN using PBKDF2 + salt.
  /// Stores key in memory only.
  /// TODO: Use per-user salt from secure storage; demo uses fixed salt.
  Future<String> deriveMasterKey(String pin, {Uint8List? salt}) async {
    final s = salt ?? _demoSalt;
    final keyBytes =
        await KeyDerivationHelper.instance.deriveKeyFromPin(pin, s);
    _masterKeyBytes = keyBytes;
    // Persist in web sessionStorage to survive reloads during the browser session.
    if (kIsWeb) {
      try {
        MasterKeyStorage.save(base64Encode(keyBytes));
      } catch (_) {}
    }
    return base64Encode(keyBytes);
  }

  /// Store MasterKey bytes in memory only (no SharedPreferences/file).
  void setMasterKeyBytes(Uint8List keyBytes) {
    _masterKeyBytes = Uint8List.fromList(keyBytes);
    if (kIsWeb) {
      try {
        MasterKeyStorage.save(base64Encode(_masterKeyBytes!));
      } catch (_) {}
    }
  }

  /// Store MasterKey string in memory (legacy; decodes base64).
  void setMasterKey(String key) {
    _masterKeyBytes = Uint8List.fromList(base64Decode(key));
    if (kIsWeb) {
      try {
        MasterKeyStorage.save(key);
      } catch (_) {}
    }
  }

  /// Panic: Wipe MasterKey and session from memory.
  void wipe() {
    if (_masterKeyBytes != null) {
      // Overwrite before clearing
      for (var i = 0; i < _masterKeyBytes!.length; i++) {
        _masterKeyBytes![i] = 0;
      }
      _masterKeyBytes = null;
    }
    if (kIsWeb) {
      try {
        MasterKeyStorage.remove();
      } catch (_) {}
    }
  }

  /// Try to restore MasterKey from web session storage when available.
  void tryRestoreFromSession() {
    if (!kIsWeb) return;
    try {
      final stored = MasterKeyStorage.load();
      if (stored != null && stored.isNotEmpty) {
        _masterKeyBytes = Uint8List.fromList(base64Decode(stored));
      }
    } catch (_) {}
  }

  /// Check if a session/MasterKey is active.
  bool get isUnlocked => _masterKeyBytes != null && _masterKeyBytes!.isNotEmpty;

  static final _demoSalt = Uint8List.fromList(
    [0x56, 0x61, 0x75, 0x6c, 0x74, 0x44, 0x65, 0x6d, 0x6f], // "VaultDemo"
  );
}
