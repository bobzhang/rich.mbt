// Tests beyond the upstream test files.

///|
test "parse_tokens gives the flattened markdown-it stream" {
  let tokens = @markdown.parse_tokens("# Title\n\nSome ~~old~~ *new* `code`")
  inspect(
    tokens.map(t => t.dump()).join("\n"),
    content=(
      #|heading_open	h1	1			
      #|text		0	Title		
      #|heading_close	h1	-1			
      #|paragraph_open	p	1			
      #|text		0	Some 		
      #|s_open	s	1			
      #|text		0	old		
      #|s_close	s	-1			
      #|text		0	 		
      #|em_open	em	1			
      #|text		0	new		
      #|em_close	em	-1			
      #|text		0	 		
      #|code_inline	code	0	code		
      #|paragraph_close	p	-1			
    ),
  )
}

///|
test "tables, ordered list start and fence info" {
  let tokens = @markdown.parse_tokens(
    "a | b\n:-|-:\n1 | 2\n\n3. x\n\n```py extra\nprint()\n```",
  )
  let interesting = tokens.filter(t => t.attrs.length() > 0 || t.info != "")
  inspect(
    interesting.map(t => t.dump()).join("\n"),
    content=(
      #|th_open	th	1		style=text-align:left	
      #|th_open	th	1		style=text-align:right	
      #|td_open	td	1		style=text-align:left	
      #|td_open	td	1		style=text-align:right	
      #|ordered_list_open	ol	1		start=3	
      #|fence	code	0	print()\n		py extra
    ),
  )
}

///|
test "unbalanced </kbd> raises (upstream: IndexError)" {
  let console = @rich.Console::new(
    width=40,
    file=@rich.StringIO::new(),
    force_terminal=true,
    environ={},
  )
  try console.print(@markdown.Markdown::new("a </kbd> b")) catch {
    @rich.StyleStackError(_) => ()
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "hyperlinks off renders link URLs" {
  let file = @rich.StringIO::new()
  let console = @rich.Console::new(
    width=40,
    file~,
    color_system=None,
    force_terminal=false,
    environ={},
  )
  console.print(
    @markdown.Markdown::new(
      "See [docs](http://x.org) ![pic](a/b/c.png)",
      hyperlinks=false,
    ),
  )
  inspect(
    file.getvalue(),
    content=(
      #|🌆 pic See docs (http://x.org)          
      #|
    ),
  )
}
