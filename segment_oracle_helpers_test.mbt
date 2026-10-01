// Helpers for segment_oracle_test.mbt (see scripts/gen_segment_tests.py).

///|
fn seg_repr(seg : @rich.Segment) -> String {
  match seg.style {
    Some(style) => "\{@rich.py_repr(seg.text)}/\{style}"
    None => @rich.py_repr(seg.text)
  }
}

///|
fn segment_ops(
  segs : Array[(String, String?)],
  cuts : Array[Int],
  cut : Int,
  width : Int,
) -> (String, String, String) raise {
  let segments = segs.map(s => {
    match s.1 {
      Some(style) => @rich.Segment::new(s.0, style=@rich.Style::parse(style))
      None => @rich.Segment::new(s.0)
    }
  })
  let divided = @rich.Segment::divide(segments, cuts)
    .map(part => part.map(seg_repr).join(","))
    .join(" | ")
  let (left, right) = segments[0].split_cells(cut)
  let split = seg_repr(left) + " + " + seg_repr(right)
  let adjusted = @rich.Segment::adjust_line_length(
      segments,
      width,
      style=@rich.Style::parse("dim"),
    )
    .map(seg_repr)
    .join(",")
  (divided, split, adjusted)
}
