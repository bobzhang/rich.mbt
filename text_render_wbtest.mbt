///|
/// Segments with their link ids renumbered by first appearance, so that two
/// renders can be compared (link ids come from a global counter).
fn normalized_segments(segments : Array[Segment]) -> Array[String] {
  let ids : Map[String, Int] = Map([])
  segments.map(s => {
    let style = match s.style {
      None => "None"
      Some(st) => {
        let link_id = st.link_id()
        let id = if link_id == "" {
          -1
        } else {
          match ids.get(link_id) {
            Some(i) => i
            None => {
              let i = ids.length()
              ids[link_id] = i
              i
            }
          }
        }
        "\{st.repr()}#\{id}"
      }
    }
    "\{py_repr(s.text)} \{style}"
  })
}

///|
test "render_joined_lines matches join + render" {
  let console = Console::new(
    file=StringIO::new(),
    width=40,
    color_system=Some("truecolor"),
    force_terminal=true,
    environ={},
  )
  let styles = [
    "bold", "red", "", "link https://x.org", "italic on blue", "none",
  ]
  let chars = ["a", "b", " ", "中", "😀"]
  let mut seed = 7
  fn next(n : Int) -> Int {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    (seed >> 8) % n
  }

  for _ in 0..<1500 {
    let lines = []
    for _ in 0..<next(5) {
      let plain = StringBuilder()
      for _ in 0..<next(8) {
        plain.write_string(chars[next(chars.length())])
      }
      let line = Text::new(text=plain.to_string())
      if next(3) == 0 {
        line.style = Def(styles[next(styles.length())])
      }
      let length = line.length()
      for _ in 0..<next(4) {
        let a = next(length + 1)
        let b = a + next(length - a + 1)
        line.spans_.push({
          start: a,
          end: b,
          style: Def(styles[next(styles.length())]),
        })
      }
      lines.push(line)
    }
    let expected = []
    Text::new(text="\n").join(lines).render_into(console, "\n", expected)
    let actual = []
    render_joined_lines(lines, console, "\n", actual)
    assert_eq(normalized_segments(actual), normalized_segments(expected))
  }
}
