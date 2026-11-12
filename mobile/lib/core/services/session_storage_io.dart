import 'dart:convert';
import 'dart:io';

File _getSessionFile() {
  return File('${Directory.systemTemp.path}/barbersmart_session_v3.json');
}

Map<String, String> _readMapSync() {
  try {
    final file = _getSessionFile();
    if (!file.existsSync()) return <String, String>{};
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    }
  } catch (_) {}
  return <String, String>{};
}

void _writeMapSync(Map<String, String> data) {
  try {
    final file = _getSessionFile();
    file.writeAsStringSync(jsonEncode(data), flush: true);
  } catch (_) {}
}

String? platformReadStorage(String key) {
  final map = _readMapSync();
  return map[key];
}

void platformWriteStorage(String key, String value) {
  final map = _readMapSync();
  map[key] = value;
  _writeMapSync(map);
}

void platformRemoveStorage(String key) {
  final map = _readMapSync();
  map.remove(key);
  _writeMapSync(map);
}
