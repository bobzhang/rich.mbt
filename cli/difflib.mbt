// Python's `difflib.get_close_matches`, used by click to suggest options.

///|
/// The number of matching characters of `a` and `b`
/// (`SequenceMatcher(None, a, b).get_matching_blocks()`, summed).
fn matching_characters(a : Array[Char], b : Array[Char]) -> Int {
  // `b2j`: positions of each character in `b` (no junk: `b` is short)
  let b2j : Map[Char, Array[Int]] = Map([])
  for j, c in b {
    match b2j.get(c) {
      Some(js) => js.push(j)
      None => b2j[c] = [j]
    }
  }
  fn longest(alo : Int, ahi : Int, blo : Int, bhi : Int) -> (Int, Int, Int) {
    let mut besti = alo
    let mut bestj = blo
    let mut bestsize = 0
    let mut j2len : Map[Int, Int] = Map([])
    for i in alo..<ahi {
      let newj2len : Map[Int, Int] = Map([])
      if b2j.get(a[i]) is Some(js) {
        for j in js {
          if j < blo {
            continue
          }
          if j >= bhi {
            break
          }
          let k = j2len.get(j - 1).unwrap_or(0) + 1
          newj2len[j] = k
          if k > bestsize {
            besti = i - k + 1
            bestj = j - k + 1
            bestsize = k
          }
        }
      }
      j2len = newj2len
    }
    (besti, bestj, bestsize)
  }

  fn total(alo : Int, ahi : Int, blo : Int, bhi : Int) -> Int {
    let (i, j, k) = longest(alo, ahi, blo, bhi)
    if k == 0 {
      return 0
    }
    let mut n = k
    if alo < i && blo < j {
      n += total(alo, i, blo, j)
    }
    if i + k < ahi && j + k < bhi {
      n += total(i + k, ahi, j + k, bhi)
    }
    n
  }

  total(0, a.length(), 0, b.length())
}

///|
/// `difflib.get_close_matches(word, possibilities)` (n=3, cutoff=0.6).
fn get_close_matches(
  word : String,
  possibilities : Array[String],
) -> Array[String] {
  let b = word.to_array()
  let scored : Array[(Double, String)] = []
  for x in possibilities {
    let a = x.to_array()
    let size = a.length() + b.length()
    if size == 0 {
      continue
    }
    let ratio = 2.0 * matching_characters(a, b).to_double() / size.to_double()
    if ratio >= 0.6 {
      scored.push((ratio, x))
    }
  }
  // heapq.nlargest(3, ...) on (score, word) tuples
  scored.sort_by((p, q) => {
    let c = q.0.compare(p.0)
    if c != 0 {
      c
    } else {
      py_compare(q.1, p.1)
    }
  })
  let out = []
  for i, p in scored {
    if i < 3 {
      out.push(p.1)
    }
  }
  out
}

///|
/// Python's string ordering (by code points).
fn py_compare(a : String, b : String) -> Int {
  let xs = a.to_array()
  let ys = b.to_array()
  for i in 0..<@cmp.minimum(xs.length(), ys.length()) {
    let c = xs[i].compare(ys[i])
    if c != 0 {
      return c
    }
  }
  xs.length().compare(ys.length())
}
