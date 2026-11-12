import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _localStorageGetItem(JSString key);

@JS('window.localStorage.setItem')
external void _localStorageSetItem(JSString key, JSString value);

@JS('window.localStorage.removeItem')
external void _localStorageRemoveItem(JSString key);

String? platformReadStorage(String key) {
  try {
    return _localStorageGetItem(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void platformWriteStorage(String key, String value) {
  try {
    _localStorageSetItem(key.toJS, value.toJS);
  } catch (_) {}
}

void platformRemoveStorage(String key) {
  try {
    _localStorageRemoveItem(key.toJS);
  } catch (_) {}
}
