class FastCache {
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  
  // Thời gian cache hợp lệ (ví dụ: 5 phút)
  static const Duration _ttl = Duration(minutes: 5);

  static void set(String key, dynamic data) {
    _memoryCache[key] = data;
    _cacheTime[key] = DateTime.now();
  }

  static dynamic get(String key) {
    if (!_memoryCache.containsKey(key)) return null;
    final time = _cacheTime[key];
    if (time == null || DateTime.now().difference(time) > _ttl) {
      return _memoryCache[key]; // Vẫn trả về để render trước (Stale)
    }
    return _memoryCache[key];
  }

  static bool isExpired(String key) {
    final time = _cacheTime[key];
    if (time == null) return true;
    return DateTime.now().difference(time) > _ttl;
  }

  static void invalidate(String keyPrefix) {
    _memoryCache.removeWhere((k, v) => k.startsWith(keyPrefix));
    _cacheTime.removeWhere((k, v) => k.startsWith(keyPrefix));
  }
}