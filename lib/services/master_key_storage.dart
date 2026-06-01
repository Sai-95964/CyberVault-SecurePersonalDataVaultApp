// Conditional export: use web implementation when available, otherwise stub.
export 'master_key_storage_stub.dart'
  if (dart.library.html) 'master_key_storage_web.dart';
