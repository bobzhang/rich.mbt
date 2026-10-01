// Port of tests/test_color.py, tests/test_color_triplet.py.

///|
test "str and repr" {
  inspect(
    @color.Color::parse("red"),
    content="Color('red', ColorType.STANDARD, number=1)",
  )
  inspect(@color.ColorSystem::EightBit, content="ColorSystem.EIGHT_BIT")
}

///|
test "system" {
  assert_eq(@color.Color::parse("default").system(), Standard)
  assert_eq(@color.Color::parse("red").system(), Standard)
  assert_eq(@color.Color::parse("#ff0000").system(), Truecolor)
}

///|
test "windows" {
  assert_eq(@color.Color::new("red", Windows, number=1).get_ansi_codes(), ["31"])
}

///|
test "truecolor" {
  assert_eq(
    @color.Color::parse("#ff0000").get_truecolor(),
    @color.ColorTriplet::new(255, 0, 0),
  )
  assert_eq(
    @color.Color::parse("red").get_truecolor(),
    @color.ColorTriplet::new(128, 0, 0),
  )
  assert_eq(
    @color.Color::parse("color(1)").get_truecolor(),
    @color.ColorTriplet::new(128, 0, 0),
  )
  assert_eq(
    @color.Color::parse("color(17)").get_truecolor(),
    @color.ColorTriplet::new(0, 0, 95),
  )
  assert_eq(
    @color.Color::parse("default").get_truecolor(),
    @color.ColorTriplet::new(0, 0, 0),
  )
  assert_eq(
    @color.Color::parse("default").get_truecolor(foreground=false),
    @color.ColorTriplet::new(255, 255, 255),
  )
  assert_eq(
    @color.Color::new("red", Windows, number=1).get_truecolor(),
    @color.ColorTriplet::new(197, 15, 31),
  )
}

///|
test "parse success" {
  assert_eq(
    @color.Color::parse("default"),
    @color.Color::new("default", Default),
  )
  assert_eq(
    @color.Color::parse("red"),
    @color.Color::new("red", Standard, number=1),
  )
  assert_eq(
    @color.Color::parse("bright_red"),
    @color.Color::new("bright_red", Standard, number=9),
  )
  assert_eq(
    @color.Color::parse("yellow4"),
    @color.Color::new("yellow4", EightBit, number=106),
  )
  assert_eq(
    @color.Color::parse("color(100)"),
    @color.Color::new("color(100)", EightBit, number=100),
  )
  assert_eq(
    @color.Color::parse("#112233"),
    @color.Color::new(
      "#112233",
      Truecolor,
      triplet=@color.ColorTriplet::new(0x11, 0x22, 0x33),
    ),
  )
  assert_eq(
    @color.Color::parse("rgb(90,100,110)"),
    @color.Color::new(
      "rgb(90,100,110)",
      Truecolor,
      triplet=@color.ColorTriplet::new(90, 100, 110),
    ),
  )
  assert_eq(
    @color.Color::parse(" RGB( 1, 2 ,3)"),
    @color.Color::new(
      "rgb( 1, 2 ,3)",
      Truecolor,
      triplet=@color.ColorTriplet::new(1, 2, 3),
    ),
  )
}

///|
test "from triplet, rgb, ansi, default" {
  let expected = @color.Color::new(
    "#102030",
    Truecolor,
    triplet=@color.ColorTriplet::new(0x10, 0x20, 0x30),
  )
  assert_eq(
    @color.Color::from_triplet(@color.ColorTriplet::new(0x10, 0x20, 0x30)),
    expected,
  )
  assert_eq(@color.Color::from_rgb(16.0, 32.0, 48.0), expected)
  assert_eq(
    @color.Color::from_ansi(1),
    @color.Color::new("color(1)", Standard, number=1),
  )
  assert_eq(@color.Color::default(), @color.Color::new("default", Default))
}

///|
test "parse error" {
  for
    bad in [
      "256", "color(256)", "rgb(999,0,0)", "rgb(0,0)", "rgb(0,0,0,0)", "nosuchcolor",
      "#xxyyzz",
    ] {
    try @color.Color::parse(bad) catch {
      _ => ()
    } noraise {
      _ => fail("expected \{bad} to fail")
    }
  }
  try @color.Color::parse("nosuchcolor") catch {
    e => inspect(e, content="'nosuchcolor' is not a valid color")
  } noraise {
    _ => fail("expected failure")
  }
}

///|
test "get_ansi_codes" {
  assert_eq(@color.Color::parse("default").get_ansi_codes(), ["39"])
  assert_eq(@color.Color::parse("default").get_ansi_codes(foreground=false), [
    "49",
  ])
  assert_eq(@color.Color::parse("red").get_ansi_codes(), ["31"])
  assert_eq(@color.Color::parse("red").get_ansi_codes(foreground=false), ["41"])
  assert_eq(@color.Color::parse("color(1)").get_ansi_codes(), ["31"])
  assert_eq(@color.Color::parse("color(1)").get_ansi_codes(foreground=false), [
    "41",
  ])
  assert_eq(@color.Color::parse("#ff0000").get_ansi_codes(), [
    "38", "2", "255", "0", "0",
  ])
  assert_eq(@color.Color::parse("#ff0000").get_ansi_codes(foreground=false), [
    "48", "2", "255", "0", "0",
  ])
}

///|
test "downgrade" {
  fn check(
    color : String,
    system : @color.ColorSystem,
    t : @color.ColorType,
    n : Int,
  ) raise {
    assert_eq(
      @color.Color::parse(color).downgrade(system),
      @color.Color::new(color, t, number=n),
    )
  }

  check("#000000", EightBit, EightBit, 16)
  check("#ffffff", EightBit, EightBit, 231)
  check("#404142", EightBit, EightBit, 237)
  check("#ff0000", EightBit, EightBit, 196)
  check("#ff0000", Standard, Standard, 1)
  check("color(9)", Standard, Standard, 9)
  check("color(20)", Standard, Standard, 4)
  check("red", Windows, Windows, 1)
  check("bright_red", Windows, Windows, 9)
  check("#ff0000", Windows, Windows, 1)
  check("color(255)", Windows, Windows, 15)
  check("#00ff00", Standard, Standard, 2)
}

///|
test "parse_rgb_hex and blend_rgb" {
  assert_eq(
    @color.parse_rgb_hex("aabbcc"),
    @color.ColorTriplet::new(0xAA, 0xBB, 0xCC),
  )
  assert_eq(
    @color.blend_rgb(
      @color.ColorTriplet::new(10, 20, 30),
      @color.ColorTriplet::new(30, 40, 50),
    ),
    @color.ColorTriplet::new(20, 30, 40),
  )
}

///|
test "color triplet" {
  assert_eq(@color.ColorTriplet::new(255, 255, 255).hex(), "#ffffff")
  assert_eq(@color.ColorTriplet::new(0, 255, 0).hex(), "#00ff00")
  assert_eq(@color.ColorTriplet::new(255, 255, 255).rgb(), "rgb(255,255,255)")
  assert_eq(@color.ColorTriplet::new(0, 255, 0).rgb(), "rgb(0,255,0)")
  assert_eq(
    @color.ColorTriplet::new(255, 255, 255).normalized(),
    (1.0, 1.0, 1.0),
  )
  assert_eq(@color.ColorTriplet::new(0, 255, 0).normalized(), (0.0, 1.0, 0.0))
}

///|
test "parse unicode whitespace and digits (oracle)" {
  fn p(s : String) -> String {
    (@color.Color::parse(s) catch { e => abort(e.to_string()) }).to_string()
  }

  inspect(p(" red "), content="Color('red', ColorType.STANDARD, number=1)")
  inspect(
    p("\u{3000}red\u{3000}"),
    content="Color('red', ColorType.STANDARD, number=1)",
  )
  assert_eq(
    p("rgb(\u{661},\u{662},\u{663})"),
    "Color('rgb(\u{661},\u{662},\u{663})', ColorType.TRUECOLOR, triplet=ColorTriplet(red=1, green=2, blue=3))",
  )
  inspect(
    p("RGB(1, 2 ,3)"),
    content="Color('rgb(1, 2 ,3)', ColorType.TRUECOLOR, triplet=ColorTriplet(red=1, green=2, blue=3))",
  )
  inspect(
    p("#FF0000"),
    content="Color('#ff0000', ColorType.TRUECOLOR, triplet=ColorTriplet(red=255, green=0, blue=0))",
  )
  assert_eq(@color.parse_rgb_hex(" f+f00"), @color.ColorTriplet::new(15, 15, 0))
}

///|
test "panic parse_rgb_hex invalid (upstream ValueError)" {
  ignore(@color.parse_rgb_hex("gg0000"))
}
