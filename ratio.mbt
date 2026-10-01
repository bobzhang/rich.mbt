// Port of rich/_ratio.py.

///|
/// An edge for `ratio_resolve`.
pub(all) struct Edge {
  size : Int?
  ratio : Int
  minimum_size : Int
} derive(Eq, Debug)

///|
/// A rational number p/q with q > 0.
priv struct Frac {
  num : Int64
  den : Int64
}

///|
fn gcd64(a : Int64, b : Int64) -> Int64 {
  let mut a = if a < 0L { -a } else { a }
  let mut b = if b < 0L { -b } else { b }
  while b != 0L {
    let t = a % b
    a = b
    b = t
  }
  a
}

///|
fn Frac::make(num : Int64, den : Int64) -> Frac {
  let g = gcd64(num, den)
  let g = if g == 0L { 1L } else { g }
  let (num, den) = if den < 0L {
    (-num / g, -den / g)
  } else {
    (num / g, den / g)
  }
  { num, den, }
}

///|
fn Frac::add(a : Frac, b : Frac) -> Frac {
  Frac::make(a.num * b.den + b.num * a.den, a.den * b.den)
}

///|
fn Frac::mul_int(a : Frac, n : Int) -> Frac {
  Frac::make(a.num * n.to_int64(), a.den)
}

///|
fn Frac::le_int(a : Frac, n : Int) -> Bool {
  a.num <= n.to_int64() * a.den
}

///|
/// Python `divmod(frac, 1)`.
fn Frac::divmod1(a : Frac) -> (Int, Frac) {
  let q = if a.num >= 0L {
    a.num / a.den
  } else {
    -((-a.num + a.den - 1L) / a.den)
  }
  (q.to_int(), Frac::make(a.num - q * a.den, a.den))
}

///|
/// Divide total space to satisfy size, ratio, and minimum_size constraints.
pub fn ratio_resolve(total : Int, edges : ArrayView[Edge]) -> Array[Int] {
  let sizes : Array[Int?] = edges.map(e => {
    match e.size {
      Some(0) | None => None
      s => s
    }
  })
  while sizes.iter().any(s => s is None) {
    let flexible_edges = []
    for index, size in sizes {
      if size is None {
        flexible_edges.push((index, edges[index]))
      }
    }
    let mut used = 0
    for s in sizes {
      used += s.unwrap_or(0)
    }
    let remaining = total - used
    if remaining <= 0 {
      return sizes.mapi((i, size) => {
        match size {
          None =>
            if edges[i].minimum_size == 0 {
              1
            } else {
              edges[i].minimum_size
            }
          Some(s) => s
        }
      })
    }
    let mut ratio_sum = 0
    for fe in flexible_edges {
      ratio_sum += if fe.1.ratio == 0 { 1 } else { fe.1.ratio }
    }
    let portion = Frac::make(remaining.to_int64(), ratio_sum.to_int64())
    let mut broke = false
    for fe in flexible_edges {
      let (index, edge) = fe
      if portion.mul_int(edge.ratio).le_int(edge.minimum_size) {
        sizes[index] = Some(edge.minimum_size)
        broke = true
        break
      }
    }
    if !broke {
      let mut remainder = Frac::make(0L, 1L)
      for fe in flexible_edges {
        let (index, edge) = fe
        let (size, rem) = portion.mul_int(edge.ratio).add(remainder).divmod1()
        remainder = rem
        sizes[index] = Some(size)
      }
      break
    }
  }
  sizes.map(s => s.unwrap_or(0))
}

///|
/// Divide an integer total in to parts based on ratios (reducing values).
pub fn ratio_reduce(
  total : Int,
  ratios : ArrayView[Int],
  maximums : ArrayView[Int],
  values : ArrayView[Int],
) -> Array[Int] {
  let ratios = ratios.mapi((i, r) => if maximums[i] != 0 { r } else { 0 })
  let mut total_ratio = 0
  for r in ratios {
    total_ratio += r
  }
  if total_ratio == 0 {
    return values.to_owned()
  }
  let mut total_remaining = total
  let result = []
  for i, ratio in ratios {
    let maximum = maximums[i]
    let value = values[i]
    if ratio != 0 && total_ratio > 0 {
      let distributed = @cmp.minimum(
        maximum,
        @color.py_round(
          ratio.to_double() *
          total_remaining.to_double() /
          total_ratio.to_double(),
        ),
      )
      result.push(value - distributed)
      total_remaining -= distributed
      total_ratio -= ratio
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Distribute an integer total in to parts based on ratios.
pub fn ratio_distribute(
  total : Int,
  ratios : ArrayView[Int],
  minimums? : ArrayView[Int],
) -> Array[Int] {
  let ratios = match minimums {
    Some(m) if m.length() != 0 =>
      ratios.mapi((i, r) => if m[i] != 0 { r } else { 0 })
    _ => ratios.to_owned()
  }
  let mut total_ratio = 0
  for r in ratios {
    total_ratio += r
  }
  guard total_ratio > 0 else { abort("Sum of ratios must be > 0") }
  let mut total_remaining = total
  let distributed_total = []
  for i, ratio in ratios {
    let minimum = match minimums {
      Some(m) => m[i]
      None => 0
    }
    let distributed = if total_ratio > 0 {
      @cmp.maximum(
        minimum,
        (ratio.to_double() *
        total_remaining.to_double() /
        total_ratio.to_double())
        .ceil()
        .to_int(),
      )
    } else {
      total_remaining
    }
    distributed_total.push(distributed)
    total_ratio -= ratio
    total_remaining -= distributed
  }
  distributed_total
}
