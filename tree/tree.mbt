// Port of rich/tree.py.

///|
/// Guide lines: (space, continue, fork, end).
pub type GuideType = (String, String, String, String)

///|
/// Guide lines used when `ConsoleOptions::ascii_only` is true.
pub let ascii_guides : GuideType = ("    ", "|   ", "+-- ", "`-- ")

///|
/// Default guide lines (normal, bold, double).
pub let tree_guides : Array[GuideType] = [
  ("    ", "│   ", "├── ", "└── "),
  ("    ", "┃   ", "┣━━ ", "┗━━ "),
  ("    ", "║   ", "╠══ ", "╚══ "),
]

///|
/// A renderable for a tree structure.
pub(all) struct Tree {
  /// The renderable or str for the tree label.
  mut label : &@rich.Renderable
  /// Style of this tree.
  mut style : @rich.StyleType
  /// Style of the guide lines.
  mut guide_style : @rich.StyleType
  /// Child trees.
  children : Array[Tree]
  /// Also display children.
  mut expanded : Bool
  /// Highlight renderable (if str).
  mut highlight : Bool
  /// Hide the root node.
  mut hide_root : Bool
}

///|
/// Create a tree. `style` defaults to `"tree"`, `guide_style` to
/// `"tree.line"`.
pub fn Tree::new(
  label : &@rich.Renderable,
  style? : &@rich.IntoStyle,
  guide_style? : &@rich.IntoStyle,
  expanded? : Bool = true,
  highlight? : Bool = false,
  hide_root? : Bool = false,
) -> Tree {
  {
    label,
    style: match style {
      Some(s) => s.into_style_type()
      None => Def("tree")
    },
    guide_style: match guide_style {
      Some(s) => s.into_style_type()
      None => Def("tree.line")
    },
    children: [],
    expanded,
    highlight,
    hide_root,
  }
}

///|
/// Add a child tree and return it. `style` and `guide_style` default to
/// this tree's values; `highlight=None` inherits this tree's setting.
pub fn Tree::add(
  self : Tree,
  label : &@rich.Renderable,
  style? : &@rich.IntoStyle,
  guide_style? : &@rich.IntoStyle,
  expanded? : Bool = true,
  highlight? : Bool? = Some(false),
) -> Tree {
  let node : Tree = {
    label,
    style: match style {
      Some(s) => s.into_style_type()
      None => self.style
    },
    guide_style: match guide_style {
      Some(s) => s.into_style_type()
      None => self.guide_style
    },
    children: [],
    expanded,
    highlight: highlight.unwrap_or(self.highlight),
    hide_root: false,
  }
  self.children.push(node)
  node
}

///|
priv struct StackFrame {
  nodes : Array[Tree]
  mut index : Int
}

///|
fn style_or_null(style : @rich.Style?) -> @rich.Style {
  match style {
    Some(s) if s.to_bool() => s
    _ => @rich.Style::null()
  }
}

///|
let space_guide = 0

///|
let continue_guide = 1

///|
let fork_guide = 2

///|
let end_guide = 3

///|
fn guide_at(guides : GuideType, index : Int) -> String {
  match index {
    0 => guides.0
    1 => guides.1
    2 => guides.2
    _ => guides.3
  }
}

///|
pub impl @rich.Renderable for Tree with fn rich_console(self, console, options) {
  let out : Array[@rich.RenderItem] = []
  let stack : Array[StackFrame] = []
  let new_line = @rich.Segment::line()
  let null_style = @rich.Style::null()
  let guide_style = console.get_style(self.guide_style, default=Def(""))
  let guide_style = if guide_style.to_bool() { guide_style } else { null_style }
  fn make_guide(index : Int, style : @rich.Style) -> @rich.Segment {
    let line = if options.ascii_only() {
      guide_at(ascii_guides, index)
    } else {
      let guide = if style.bold() is Some(true) {
        1
      } else if style.underline2() is Some(true) {
        2
      } else {
        0
      }
      guide_at(
        tree_guides[if options.legacy_windows { 0 } else { guide }],
        index,
      )
    }
    @rich.Segment::new(line, style~)
  }

  let levels : Array[@rich.Segment] = [make_guide(continue_guide, guide_style)]
  stack.push({ nodes: [self], index: 0, })
  let guide_style_stack = @rich.StyleStack::new(
    console.get_style(self.guide_style),
  )
  let style_stack = @rich.StyleStack::new(console.get_style(self.style))
  let remove_guide_styles = @rich.Style::new(bold=false, underline2=false)
  let mut depth = 0
  while stack.pop() is Some(stack_node) {
    if stack_node.index >= stack_node.nodes.length() {
      ignore(levels.pop())
      if levels.length() > 0 {
        let guide_style = style_or_null(levels[levels.length() - 1].style)
        levels[levels.length() - 1] = make_guide(fork_guide, guide_style)
        ignore(guide_style_stack.pop())
        ignore(style_stack.pop())
      }
      continue
    }
    let node = stack_node.nodes[stack_node.index]
    stack_node.index += 1
    let last = stack_node.index == stack_node.nodes.length()
    stack.push(stack_node)
    if last {
      levels[levels.length() - 1] = make_guide(
        end_guide,
        style_or_null(levels[levels.length() - 1].style),
      )
    }
    let guide_style = guide_style_stack.current() +
      console.get_style(node.guide_style)
    let style = style_stack.current() + console.get_style(node.style)
    let skip = if self.hide_root { 2 } else { 1 }
    let prefix = if skip < levels.length() {
      levels[skip:].to_owned()
    } else {
      []
    }
    let mut prefix_width = 0
    for level in prefix {
      prefix_width += level.cell_length()
    }
    let renderable_lines = console.render_lines(
      @rich.Styled::new(node.label, style),
      options=options.update(
        width=options.max_width - prefix_width,
        highlight=Some(self.highlight),
        height=None,
      ),
      pad=options.justify is Some(_),
    )
    if !(depth == 0 && self.hide_root) {
      for i, line in renderable_lines {
        if prefix.length() > 0 {
          for
            s in @rich.Segment::apply_style(
              prefix,
              style=style.background_style(),
              post_style=remove_guide_styles,
            ) {
            out.push(Seg(s))
          }
        }
        for s in line {
          out.push(Seg(s))
        }
        out.push(Seg(new_line))
        if i == 0 && prefix.length() > 0 {
          let last_index = prefix.length() - 1
          prefix[last_index] = make_guide(
            if last {
              space_guide
            } else {
              continue_guide
            },
            style_or_null(prefix[last_index].style),
          )
        }
      }
    }
    if node.expanded && node.children.length() > 0 {
      levels[levels.length() - 1] = make_guide(
        if last {
          space_guide
        } else {
          continue_guide
        },
        style_or_null(levels[levels.length() - 1].style),
      )
      levels.push(
        make_guide(
          if node.children.length() == 1 {
            end_guide
          } else {
            fork_guide
          },
          guide_style,
        ),
      )
      style_stack.push(console.get_style(node.style))
      guide_style_stack.push(console.get_style(node.guide_style))
      stack.push({ nodes: node.children, index: 0, })
      depth += 1
    }
  }
  out
}

///|
pub impl @rich.Renderable for Tree with fn rich_measure(self, console, options) {
  let stack : Array[StackFrame] = [{ nodes: [self], index: 0, }]
  let mut minimum = 0
  let mut maximum = 0
  let mut level = 0
  while stack.pop() is Some(iter_tree) {
    if iter_tree.index >= iter_tree.nodes.length() {
      level -= 1
      continue
    }
    let tree = iter_tree.nodes[iter_tree.index]
    iter_tree.index += 1
    stack.push(iter_tree)
    let m = @rich.Measurement::get(console, options, tree.label)
    let indent = level * 4
    minimum = @cmp.maximum(m.minimum + indent, minimum)
    maximum = @cmp.maximum(m.maximum + indent, maximum)
    if tree.expanded && tree.children.length() > 0 {
      stack.push({ nodes: tree.children, index: 0, })
      level += 1
    }
  }
  Some(@rich.Measurement::new(minimum, maximum))
}
