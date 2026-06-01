import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_metadata.dart';

/// Firestore: vault_docs/{userId}/documents/{documentId}
/// Fields: id, name, mimeType, uploadedAt, blobBase64, blobHash (base64), tags.
/// Encrypted blobs stored directly in Firestore as Base64 (optimized for small demo files <1MB).
///
/// When [useLocalBackend] is true (default), documents persist via SharedPreferences
/// so the app runs without a Firebase project. Set `--dart-define=USE_LOCAL_BACKEND=false`
/// and configure Firebase to use the cloud backend.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const _collectionVault = 'vault_docs';
  static const _localPrefsKey = 'cybervault_local_documents';

  /// Local in-memory + disk fallback when Firebase is not configured.
  static bool useLocalBackend = true;

  Map<String, Map<String, Map<String, dynamic>>>? _localCache;
  bool _localLoaded = false;

  CollectionReference<Map<String, dynamic>> _userDocs(String userId) =>
      FirebaseFirestore.instance
          .collection(_collectionVault)
          .doc(userId)
          .collection('documents');

  Future<void> _ensureLocalLoaded() async {
    if (_localLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _localCache = decoded.map(
        (userId, docs) => MapEntry(
          userId,
          (docs as Map<String, dynamic>).map(
            (id, data) => MapEntry(id, Map<String, dynamic>.from(data)),
          ),
        ),
      );
    } else {
      _localCache = {};
    }
    _localLoaded = true;
  }

  Future<void> _persistLocal() async {
    if (_localCache == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localPrefsKey, jsonEncode(_localCache));
  }

  Map<String, Map<String, dynamic>> _userLocalDocs(String userId) {
    _localCache ??= {};
    return _localCache!.putIfAbsent(userId, () => {});
  }

  DocumentMetadata _metadataFromMap(String docId, Map<String, dynamic> d) {
    final uploadedAtRaw = d['uploadedAt'];
    final DateTime uploadedAt;
    if (uploadedAtRaw is String) {
      uploadedAt = DateTime.tryParse(uploadedAtRaw) ?? DateTime.now();
    } else if (uploadedAtRaw is Timestamp) {
      uploadedAt = uploadedAtRaw.toDate();
    } else {
      uploadedAt = DateTime.now();
    }
    List<int>? blobHash;
    if (d['blobHash'] != null && d['blobHash'] is String) {
      blobHash = base64Decode(d['blobHash'] as String);
    }
    return DocumentMetadata(
      id: d['id'] as String? ?? docId,
      name: d['name'] as String? ?? 'Unknown',
      mimeType: d['mimeType'] as String? ?? 'application/octet-stream',
      uploadedAt: uploadedAt,
      tags: _toStringList(d['tags']),
      blobBase64: d['blobBase64'] as String?,
      blobHash: blobHash,
    );
  }

  Future<List<DocumentMetadata>> _loadDocumentsLocal(String userId) async {
    await _ensureLocalLoaded();
    final docs = _userLocalDocs(userId);
    final list = docs.entries
        .map((e) => _metadataFromMap(e.key, e.value))
        .toList();
    list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return list;
  }

  Future<void> _writeDocumentLocal({
    required String userId,
    required DocumentMetadata metadata,
    required String blobBase64,
    required List<int> blobHash,
  }) async {
    await _ensureLocalLoaded();
    _userLocalDocs(userId)[metadata.id] = {
      'id': metadata.id,
      'name': metadata.name,
      'mimeType': metadata.mimeType,
      'uploadedAt': metadata.uploadedAt.toIso8601String(),
      'blobBase64': blobBase64,
      'blobHash': base64Encode(blobHash),
      'tags': metadata.tags ?? [],
    };
    await _persistLocal();
  }

  Future<void> _deleteDocumentLocal(String userId, String documentId) async {
    await _ensureLocalLoaded();
    _userLocalDocs(userId).remove(documentId);
    await _persistLocal();
  }

  /// Load all documents from Firestore (metadata + blobBase64), ordered by uploadedAt desc.
  Future<List<DocumentMetadata>> loadDocuments(String userId) async {
    if (useLocalBackend) return _loadDocumentsLocal(userId);

    final snapshot = await _userDocs(userId)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return _metadataFromMap(doc.id, doc.data());
    }).toList();
  }

  /// Alias for loadDocuments (keeps existing callers working).
  Future<List<DocumentMetadata>> loadDocumentMetadata(String userId) =>
      loadDocuments(userId);

  List<String>? _toStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  /// Write full document to Firestore (including encrypted blob as Base64).
  Future<void> writeDocument({
    required String userId,
    required DocumentMetadata metadata,
    required String blobBase64,
    required List<int> blobHash,
  }) async {
    if (useLocalBackend) {
      return _writeDocumentLocal(
        userId: userId,
        metadata: metadata,
        blobBase64: blobBase64,
        blobHash: blobHash,
      );
    }

    await _userDocs(userId).doc(metadata.id).set({
      'id': metadata.id,
      'name': metadata.name,
      'mimeType': metadata.mimeType,
      'uploadedAt': Timestamp.fromDate(metadata.uploadedAt),
      'blobBase64': blobBase64,
      'blobHash': base64Encode(blobHash),
      'tags': metadata.tags ?? [],
    });
  }

  /// Delete document from Firestore.
  Future<void> deleteDocument(String userId, String documentId) async {
    if (useLocalBackend) {
      return _deleteDocumentLocal(userId, documentId);
    }
    await _userDocs(userId).doc(documentId).delete();
  }

  /// Alias for deleteDocument.
  Future<void> deleteMetadata(String userId, String documentId) =>
      deleteDocument(userId, documentId);
}
