// Formatter conversions checked against Python logging.Formatter.

///|
test "formatter numeric conversions match Python" {
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1.23e+03",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1.2e+03",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created) .2f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    " 1234.57",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message).3r").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "'ab",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)E").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1.234567E+03",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1234.57",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)#.3g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1.23e+03",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)+.1e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "+1.2e+03",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(levelno).3e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "2.000e+01",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)012.3f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "00001234.567",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)-12.2g|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "1.2e+03     |",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message)10.4s|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1234.567),
    ),
    "      abcd|",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.23e-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.2e-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created) .2f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    " 0.00",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message).3r").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "'ab",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)E").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.234500E-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.2345e-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)#.3g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.23e-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)+.1e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "+1.2e-05",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(levelno).3e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "2.000e+01",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)012.3f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "00000000.000",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)-12.2g|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "1.2e-05     |",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message)10.4s|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=1.2345e-05),
    ),
    "      abcd|",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.88e+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created).2g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.9e+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created) .2f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    " 98765432.10",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message).3r").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "'ab",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)E").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.876543E+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.87654e+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)#.3g").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.88e+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)+.1e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "+9.9e+07",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(levelno).3e").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "2.000e+01",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)012.3f").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "98765432.100",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(created)-12.2g|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "9.9e+07     |",
  )
  assert_eq(
    @logging.Formatter::new(fmt="%(message)10.4s|").format_message(
      @logging.LogRecord::new(20, "abcdef", created=98765432.1),
    ),
    "      abcd|",
  )
}
