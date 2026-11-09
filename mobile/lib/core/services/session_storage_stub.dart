final Map<String, String> _memoryStore = <String, String>{};

String? platformReadStorage(String key) => _memoryStore[key];

void platformWriteStorage(String key, String value) {
  _memoryStore[key] = value;
}

void platformRemoveStorage(String key) {
  _memoryStore.remove(key);
}
