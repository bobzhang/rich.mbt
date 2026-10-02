// Text.render (upstream `Text.render`) and a fused
// `Text("\n").join(lines).render(...)` used by `Text.__rich_console__`.

///|
/// Render events `(offset, leaving, seq)` packed in a UInt64 (biased offset,
/// leaving flag, sequence number) so that sorting the integers sorts by
/// `(offset, leaving)` and keeps equal keys in sequence order, like
/// upstream's stable `spans.sort(key=itemgetter(0, 1))`.
fn pack_event(offset : Int, leaving : Bool, seq : Int) -> UInt64 {
  ((offset.to_int64() + 0x8000_0000L).reinterpret_as_uint64() << 32) |
  (if leaving { 0x8000_0000UL } else { 0UL }) |
  seq.to_uint64()
}

///|
fn event_offset(e : UInt64) -> Int {
  ((e >> 32).reinterpret_as_int64() - 0x8000_0000L).to_int()
}

///|
fn event_leaving(e : UInt64) -> Bool {
  (e & 0x8000_0000UL) != 0
}

///|
fn event_seq(e : UInt64) -> Int {
  (e & 0x7FFF_FFFFUL).to_int()
}

///|
/// The open styles of a render (upstream's `stack` and `style_cache` in
/// `Text.render`): style ids are kept sorted, and the current style is
/// the combination of their styles in id order.
priv struct ActiveStyles {
  style_map : FixedArray[Style]
  stack : Array[Int]
  mut cache : Map[Array[Int], Style]?
}

///|
fn ActiveStyles::new(style_map : FixedArray[Style]) -> ActiveStyles {
  { style_map, stack: [], cache: None, }
}

///|
fn ActiveStyles::enter(self : ActiveStyles, id : Int) -> Unit {
  match self.stack.binary_search(id) {
    Ok(idx) | Err(idx) => self.stack.insert(idx, id)
  }
}

///|
fn ActiveStyles::leave(self : ActiveStyles, id : Int) -> Unit {
  match self.stack.binary_search(id) {
    Ok(idx) => self.stack.remove(idx) |> ignore
    Err(_) => ()
  }
}

///|
fn ActiveStyles::current(self : ActiveStyles) -> Style {
  let stack = self.stack
  let style_map = self.style_map
  // Fast paths: one style, or two plain styles (`+` is memoized and
  // without links/meta the result does not depend on the cache).
  if stack.length() == 1 {
    return style_map[stack[0]]
  }
  if stack.length() == 2 {
    let a = style_map[stack[0]]
    let b = style_map[stack[1]]
    if a.is_plain() && b.is_plain() {
      return a + b
    }
  }
  let cache = match self.cache {
    Some(cache) => cache
    None => {
      let cache = Map([])
      self.cache = Some(cache)
      cache
    }
  }
  match cache.get(stack) {
    Some(s) => s
    None => {
      let mut s = style_map[stack[0]]
      for k in 1..<stack.length() {
        s = s + style_map[stack[k]]
      }
      cache[stack.copy()] = s
      s
    }
  }
}

///|
/// `render` appending the segments to `result`.
fn Text::render_into(
  self : Text,
  console : Console,
  end : String,
  result : Array[Segment],
) -> Unit raise {
  let text = self.plain()
  if self.spans_.is_empty() {
    result.push(Segment::new(text))
    if end != "" {
      result.push(Segment::new(end))
    }
    return
  }
  let null = Def("")
  let n = self.spans_.length()
  let style_map : FixedArray[Style] = FixedArray::make(n + 1, null_style)
  for i, span in self.spans_ {
    style_map[i + 1] = console.get_style(span.style, default=null)
  }
  style_map[0] = console.get_style(self.style, default=null)
  // sequence numbers: 0 enters the base style, 1..=n enter the spans,
  // n+1..=2n leave them and 2n+1 leaves the base style
  let events : Array[UInt64] = Array(capacity=2 * n + 2)
  events.push(pack_event(0, false, 0))
  for i, span in self.spans_ {
    events.push(pack_event(span.start, false, i + 1))
  }
  for i, span in self.spans_ {
    events.push(pack_event(span.end, true, n + i + 1))
  }
  events.push(pack_event(text.length(), true, 2 * n + 1))
  events.sort()
  let active = ActiveStyles::new(style_map)
  let text_length = text.length()
  for i in 0..<(events.length() - 1) {
    let e = events[i]
    let offset = event_offset(e)
    let seq = event_seq(e)
    let next_offset = event_offset(events[i + 1])
    if event_leaving(e) {
      active.leave(if seq > n { seq - n } else { 0 })
    } else {
      active.enter(seq)
    }
    if next_offset > offset {
      let segment_text = if offset == 0 && next_offset == text_length {
        text
      } else {
        text.view(start_offset=offset, end_offset=next_offset).to_owned()
      }
      result.push(Segment::new(segment_text, style=active.current()))
    }
  }
  if end != "" {
    result.push(Segment::new(end))
  }
}

///|
/// `Text::new(text="\n").join(lines).render_into(console, end, out)` without
/// building the joined Text: the same segments (the same style lookups in
/// the same order, the same segment boundaries) from the lines themselves.
///
/// In the joined text every line contributes a span for its style (when
/// set) and its own spans, all within the line, so the open styles never
/// cross a newline: events can be generated and sorted line by line, and a
/// segment only crosses lines where there is no event at either side of a
/// newline. Lines with spans outside `0..=length` (which would cross into
/// the following lines) use the general path.
fn render_joined_lines(
  lines : Array[Text],
  console : Console,
  end : String,
  out : Array[Segment],
) -> Unit raise {
  let line_count = lines.length()
  let mut span_count = 0
  for line in lines {
    let length = line.length_
    let general = length != line.plain().length() ||
      line.spans_
      .iter()
      .any(span => span.start < 0 || span.start > span.end || span.end > length)
    if general {
      Text::new(text="\n").join(lines).render_into(console, end, out)
      return
    }
    if line.style.to_bool() {
      span_count += 1
    }
    span_count += line.spans_.length()
  }
  if span_count == 0 {
    // the joined text has no spans: a single segment
    out.push(Segment::new(lines.map(line => line.plain()).join("\n")))
    if end != "" {
      out.push(Segment::new(end))
    }
    return
  }
  // style ids in the order of the joined text's spans; 0 is its own style
  let null = Def("")
  let style_map : FixedArray[Style] = FixedArray::make(
    span_count + 1,
    null_style,
  )
  let first_ids : FixedArray[Int] = FixedArray::make(line_count, 0)
  let mut id = 0
  for i, line in lines {
    first_ids[i] = id + 1
    if line.style.to_bool() {
      id += 1
      style_map[id] = console.get_style(line.style, default=null)
    }
    for span in line.spans_ {
      id += 1
      style_map[id] = console.get_style(span.style, default=null)
    }
  }
  style_map[0] = console.get_style(null, default=null)
  // offset of each line in the joined text
  let starts : FixedArray[Int] = FixedArray::make(line_count + 1, 0)
  for i, line in lines {
    starts[i + 1] = starts[i] + line.length_ + 1
  }
  let total_length = starts[line_count] - 1
  // text of the joined text between `a` and `b`, with `a` in line `cursor`
  let mut cursor = 0
  fn slice(a : Int, b : Int) -> String {
    while cursor + 1 < line_count && starts[cursor + 1] <= a {
      cursor += 1
    }
    let plain = lines[cursor].plain()
    let base = starts[cursor]
    let line_end = base + plain.length()
    if b <= line_end {
      return if a == base && b == line_end {
        plain
      } else {
        plain.view(start_offset=a - base, end_offset=b - base).to_owned()
      }
    }
    let buf = StringBuilder(size_hint=(b - a) * 2)
    buf.write_view(plain.view(start_offset=a - base))
    let mut pos = line_end
    let mut index = cursor
    while pos < b {
      buf.write_char('\n')
      pos += 1
      index += 1
      if pos >= b {
        break
      }
      let next = lines[index].plain()
      let take = @cmp.minimum(b - pos, next.length())
      buf.write_view(next.view(end_offset=take))
      pos += take
    }
    buf.to_string()
  }

  let active = ActiveStyles::new(style_map)
  active.enter(0)
  let mut group_offset = 0
  let events : Array[UInt64] = []
  for i, line in lines {
    // events of this line, in local offsets; sequence numbers: entering
    // `k` is `k`, leaving it is `n + k` (`k` counts the style span first)
    let has_style = line.style.to_bool()
    let length = line.length_
    let n = line.spans_.length() + (if has_style { 1 } else { 0 })
    if n == 0 {
      continue
    }
    events.clear()
    if has_style {
      events.push(pack_event(0, false, 0))
    }
    let shift = if has_style { 1 } else { 0 }
    for k, span in line.spans_ {
      events.push(pack_event(span.start, false, k + shift))
    }
    if has_style {
      events.push(pack_event(length, true, n))
    }
    for k, span in line.spans_ {
      events.push(pack_event(span.end, true, n + k + shift))
    }
    events.sort()
    let base = starts[i]
    let first_id = first_ids[i]
    for e in events {
      let offset = base + event_offset(e)
      if offset > group_offset {
        out.push(
          Segment::new(slice(group_offset, offset), style=active.current()),
        )
        group_offset = offset
      }
      let seq = event_seq(e)
      if event_leaving(e) {
        active.leave(first_id + seq - n)
      } else {
        active.enter(first_id + seq)
      }
    }
  }
  if total_length > group_offset {
    out.push(
      Segment::new(slice(group_offset, total_length), style=active.current()),
    )
  }
  if end != "" {
    out.push(Segment::new(end))
  }
}
