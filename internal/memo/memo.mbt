// Bounded memo tables, standing in for upstream's `functools.lru_cache`.

///|
/// A memo table holding at most `capacity` entries. When it is full, the
/// oldest entry is evicted (insertion order), so memory stays bounded like
/// upstream's `lru_cache(maxsize=...)`.
pub struct Memo[K, V] {
  priv map : Map[K, V]
  priv capacity : Int
}

///|
/// Create an empty memo table holding at most `capacity` entries.
pub fn[K : Hash + Eq, V] Memo::new(capacity : Int) -> Memo[K, V] {
  { map: Map([]), capacity, }
}

///|
/// The value memoized for `key`.
pub fn[K : Hash + Eq, V] Memo::get(self : Memo[K, V], key : K) -> V? {
  self.map.get(key)
}

///|
/// Memoize `value` for `key`, evicting the oldest entry when full.
pub fn[K : Hash + Eq, V] Memo::set(
  self : Memo[K, V],
  key : K,
  value : V,
) -> Unit {
  if self.map.length() >= self.capacity && !self.map.contains(key) {
    let mut oldest = None
    for k, _ in self.map {
      oldest = Some(k)
      break
    }
    if oldest is Some(k) {
      self.map.remove(k)
    }
  }
  self.map[key] = value
}

///|
/// Number of memoized entries.
pub fn[K, V] Memo::length(self : Memo[K, V]) -> Int {
  self.map.length()
}

///|
/// Remove every entry.
pub fn[K, V] Memo::clear(self : Memo[K, V]) -> Unit {
  self.map.clear()
}
