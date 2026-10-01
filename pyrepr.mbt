// Python-compatible repr helpers.

///|
/// Python `repr()` of a string.
pub fn py_repr(s : String) -> String {
  @pystr.repr(s)
}

///|
fn py_bool(b : Bool) -> String {
  if b {
    "True"
  } else {
    "False"
  }
}

///|
/// Python `repr(float)`.
pub fn py_float_repr(d : Double) -> String {
  if d.is_nan() {
    return "nan"
  }
  if d.is_pos_inf() {
    return "inf"
  }
  if d.is_neg_inf() {
    return "-inf"
  }
  if d == 0.0 {
    return if 1.0 / d < 0.0 { "-0.0" } else { "0.0" }
  }
  let (negative, digits, decpt) = shortest_digits(d)
  let sign = if negative { "-" } else { "" }
  let nd = digits.length()
  if decpt > 16 || decpt <= -4 {
    // scientific: d.ddde[+-]XX
    let exp = decpt - 1
    let mantissa = if nd == 1 {
      digits
    } else {
      digits.view(end_offset=1).to_owned() +
      "." +
      digits.view(start_offset=1).to_owned()
    }
    let exp_sign = if exp < 0 { "-" } else { "+" }
    let e = exp.abs()
    let exp_text = if e < 10 { "0\{e}" } else { e.to_string() }
    sign + mantissa + "e" + exp_sign + exp_text
  } else if decpt <= 0 {
    sign + "0." + "0".repeat(-decpt) + digits
  } else if decpt >= nd {
    sign + digits + "0".repeat(decpt - nd) + ".0"
  } else {
    sign +
    digits.view(end_offset=decpt).to_owned() +
    "." +
    digits.view(start_offset=decpt).to_owned()
  }
}

///|
/// Shortest round-trip digits of a finite non-zero double, as
/// `(negative, digits, decpt)` meaning `0.digits × 10^decpt`.
fn shortest_digits(d : Double) -> (Bool, String, Int) {
  let s = d.to_string()
  let negative = s.has_prefix("-")
  let s = if negative { s.view(start_offset=1).to_owned() } else { s }
  let (mantissa, exp) = match s.find("e") {
    Some(i) =>
      (
        s.view(end_offset=i).to_owned(),
        @string.parse_int(s.view(start_offset=i + 1).to_owned()) catch {
          _ => 0
        },
      )
    None => (s, 0)
  }
  let (int_part, frac_part) = match mantissa.find(".") {
    Some(i) =>
      (
        mantissa.view(end_offset=i).to_owned(),
        mantissa.view(start_offset=i + 1).to_owned(),
      )
    None => (mantissa, "")
  }
  let all = int_part + frac_part
  // strip leading zeros
  let mut lead = 0
  while lead < all.length() - 1 && all[lead] == '0' {
    lead += 1
  }
  let mut digits = all.view(start_offset=lead).to_owned()
  let decpt = int_part.length() - lead + exp
  // strip trailing zeros
  let mut end = digits.length()
  while end > 1 && digits[end - 1] == '0' {
    end -= 1
  }
  digits = digits.view(end_offset=end).to_owned()
  (negative, digits, decpt)
}

///|
/// Decompose a finite double into `(negative, mantissa, exponent)` with
/// `|d| = mantissa * 2^exponent`.
fn decompose(d : Double) -> (Bool, UInt64, Int) {
  let bits = d.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let exp_bits = ((bits >> 52) & 0x7ffUL).to_int()
  let frac = bits & 0xfffffffffffffUL
  if exp_bits == 0 {
    (negative, frac, -1074)
  } else {
    (negative, frac | 0x10000000000000UL, exp_bits - 1075)
  }
}

///|
fn big(n : Int) -> @bigint.BigInt {
  @bigint.BigInt::from_int(n)
}

///|
fn pow_big(base : Int, exp : Int) -> @bigint.BigInt {
  big(base).pow(big(exp))
}

///|
/// `round_half_even(mantissa * 2^exponent / 10^k)` computed exactly.
fn exact_round(mantissa : UInt64, exponent : Int, k : Int) -> @bigint.BigInt {
  let mut num = @bigint.BigInt::from_uint64(mantissa)
  let mut den = big(1)
  if exponent >= 0 {
    num = num * pow_big(2, exponent)
  } else {
    den = den * pow_big(2, -exponent)
  }
  if k >= 0 {
    den = den * pow_big(10, k)
  } else {
    num = num * pow_big(10, -k)
  }
  let q = num / den
  let r = num - q * den
  let twice = r * big(2)
  if twice > den || (twice == den && q % big(2) != big(0)) {
    q + big(1)
  } else {
    q
  }
}

///|
/// Python `format(d, ".{precision}f")`: fixed-point, correctly rounded
/// (round half to even on the exact binary value).
pub fn py_format_fixed(d : Double, precision : Int) -> String {
  if d.is_nan() {
    return "nan"
  }
  if d.is_pos_inf() {
    return "inf"
  }
  if d.is_neg_inf() {
    return "-inf"
  }
  let (negative, mantissa, exponent) = decompose(d)
  let n = exact_round(mantissa, exponent, -precision)
  let digits = n.to_string()
  let digits = if digits.length() <= precision {
    "0".repeat(precision - digits.length() + 1) + digits
  } else {
    digits
  }
  let int_part = digits.view(end_offset=digits.length() - precision).to_owned()
  let frac_part = digits
    .view(start_offset=digits.length() - precision)
    .to_owned()
  let sign = if negative { "-" } else { "" }
  if precision == 0 {
    sign + int_part
  } else {
    sign + int_part + "." + frac_part
  }
}

///|
/// Round to `sig` significant digits: `(negative, digits, x)` meaning
/// `d.ddd × 10^x` with `digits.length() == sig`.
fn round_significant(d : Double, sig : Int) -> (Bool, String, Int) {
  let (negative, mantissa, exponent) = decompose(d)
  let (_, _, decpt) = shortest_digits(d)
  let mut x = decpt - 1
  let mut n = exact_round(mantissa, exponent, x - (sig - 1))
  let lower = pow_big(10, sig - 1)
  let upper = pow_big(10, sig)
  if n < lower {
    x -= 1
    n = exact_round(mantissa, exponent, x - (sig - 1))
  }
  if n >= upper {
    x += 1
    n = exact_round(mantissa, exponent, x - (sig - 1))
  }
  (negative, n.to_string(), x)
}

///|
/// Python `format(d, "g")` (6 significant digits, trailing zeros removed).
pub fn py_format_g(d : Double) -> String {
  if d.is_nan() {
    return "nan"
  }
  if d.is_pos_inf() {
    return "inf"
  }
  if d.is_neg_inf() {
    return "-inf"
  }
  if d == 0.0 {
    return if 1.0 / d < 0.0 { "-0" } else { "0" }
  }
  let precision = 6
  let (negative, digits, x) = round_significant(d, precision)
  let sign = if negative { "-" } else { "" }
  fn strip(s : String) -> String {
    if !s.contains(".") {
      return s
    }
    let mut end = s.length()
    while end > 0 && s[end - 1] == '0' {
      end -= 1
    }
    if end > 0 && s[end - 1] == '.' {
      end -= 1
    }
    s.view(end_offset=end).to_owned()
  }

  if x < -4 || x >= precision {
    let mantissa = strip(
      digits.view(end_offset=1).to_owned() +
      "." +
      digits.view(start_offset=1).to_owned(),
    )
    let exp_sign = if x < 0 { "-" } else { "+" }
    let e = x.abs()
    sign +
    mantissa +
    "e" +
    exp_sign +
    (if e < 10 { "0\{e}" } else { e.to_string() })
  } else if x >= 0 {
    let int_part = digits.view(end_offset=x + 1).to_owned()
    let frac = digits.view(start_offset=x + 1).to_owned()
    sign + strip(int_part + "." + frac)
  } else {
    sign + strip("0." + "0".repeat(-x - 1) + digits)
  }
}

///|
/// Insert thousands separators (Python's `,` format option) into the
/// integer part of a formatted number.
pub fn py_group_thousands(s : String) -> String {
  let (sign, rest) = if s.has_prefix("-") {
    ("-", s.view(start_offset=1).to_owned())
  } else {
    ("", s)
  }
  let (int_part, tail) = match rest.find(".") {
    Some(i) =>
      (rest.view(end_offset=i).to_owned(), rest.view(start_offset=i).to_owned())
    None => (rest, "")
  }
  let buf = StringBuilder()
  let n = int_part.length()
  for i in 0..<n {
    if i > 0 && (n - i) % 3 == 0 {
      buf.write_char(',')
    }
    buf.write_char(int_part[i].to_int().unsafe_to_char())
  }
  sign + buf.to_string() + tail
}

///|
/// Python `repr()` of a JSON value interpreted as the Python value it
/// came from (dicts, lists, str, int/float, True/False/None). Integral
/// numbers are shown as ints.
pub fn py_json_repr(value : Json) -> String {
  match value {
    Null => "None"
    True => "True"
    False => "False"
    Number(n, ..) =>
      if n == n.floor() && n.abs() < 1.0e16 {
        n.to_int64().to_string()
      } else {
        py_float_repr(n)
      }
    String(s) => py_repr(s)
    Array(items) => "[" + items.map(py_json_repr).join(", ") + "]"
    Object(m) => {
      let parts = []
      for k, v in m {
        parts.push(py_repr(k) + ": " + py_json_repr(v))
      }
      "{" + parts.join(", ") + "}"
    }
  }
}
