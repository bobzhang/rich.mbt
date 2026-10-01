// URL normalization, checked against markdown-it-py (normalizeLink,
// normalizeLinkText, validateLink).

///|
test "normalize_link / normalize_link_text / validate_link" {
  assert_eq(
    @markdown.normalize_link("http://example.com/a b"),
    "http://example.com/a%20b",
  )
  assert_eq(
    @markdown.normalize_link_text("http://example.com/a b"),
    "http://example.com/a b",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("http://example.com/a b")),
    true,
  )
  assert_eq(
    @markdown.normalize_link("http://例子.测试/路径?q=1#frag"),
    "http://xn--fsqu00a.xn--0zwm56d/%E8%B7%AF%E5%BE%84?q=1#frag",
  )
  assert_eq(
    @markdown.normalize_link_text("http://例子.测试/路径?q=1#frag"),
    "http://例子.测试/路径?q=1#frag",
  )
  assert_eq(
    @markdown.validate_link(
      @markdown.normalize_link("http://例子.测试/路径?q=1#frag"),
    ),
    true,
  )
  assert_eq(
    @markdown.normalize_link("HTTP://EXAMPLE.COM/%7e"),
    "HTTP://EXAMPLE.COM/%7e",
  )
  assert_eq(
    @markdown.normalize_link_text("HTTP://EXAMPLE.COM/%7e"),
    "HTTP://EXAMPLE.COM/~",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("HTTP://EXAMPLE.COM/%7e")),
    true,
  )
  assert_eq(
    @markdown.normalize_link("mailto:user@ドメイン.jp"),
    "mailto:user@xn--eckwd4c7c.jp",
  )
  assert_eq(
    @markdown.normalize_link_text("mailto:user@ドメイン.jp"),
    "mailto:user@ドメイン.jp",
  )
  assert_eq(
    @markdown.validate_link(
      @markdown.normalize_link("mailto:user@ドメイン.jp"),
    ),
    true,
  )
  assert_eq(@markdown.normalize_link("//host.com/x"), "//host.com/x")
  assert_eq(@markdown.normalize_link_text("//host.com/x"), "//host.com/x")
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("//host.com/x")),
    true,
  )
  assert_eq(@markdown.normalize_link("foo\\bar"), "foo%5Cbar")
  assert_eq(@markdown.normalize_link_text("foo\\bar"), "foo\\bar")
  assert_eq(@markdown.validate_link(@markdown.normalize_link("foo\\bar")), true)
  assert_eq(
    @markdown.normalize_link("http://user:pw@host:8080/p"),
    "http://user:pw@host:8080/p",
  )
  assert_eq(
    @markdown.normalize_link_text("http://user:pw@host:8080/p"),
    "http://user:pw@host:8080/p",
  )
  assert_eq(
    @markdown.validate_link(
      @markdown.normalize_link("http://user:pw@host:8080/p"),
    ),
    true,
  )
  assert_eq(
    @markdown.normalize_link("skype:名前"),
    "skype:%E5%90%8D%E5%89%8D",
  )
  assert_eq(@markdown.normalize_link_text("skype:名前"), "skype:名前")
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("skype:名前")),
    true,
  )
  assert_eq(
    @markdown.normalize_link("http://[::1]:80/"),
    "http://%5B::1%5D:80/",
  )
  assert_eq(
    @markdown.normalize_link_text("http://[::1]:80/"),
    "http://[::1]:80/",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("http://[::1]:80/")),
    true,
  )
  assert_eq(
    @markdown.normalize_link("https://xn--fsqu00a.com/%E2%82%AC"),
    "https://xn--fsqu00a.com/%E2%82%AC",
  )
  assert_eq(
    @markdown.normalize_link_text("https://xn--fsqu00a.com/%E2%82%AC"),
    "https://例子.com/€",
  )
  assert_eq(
    @markdown.validate_link(
      @markdown.normalize_link("https://xn--fsqu00a.com/%E2%82%AC"),
    ),
    true,
  )
  assert_eq(@markdown.normalize_link("a%2fb%zz"), "a%2fb%25zz")
  assert_eq(@markdown.normalize_link_text("a%2fb%zz"), "a%2Fb%zz")
  assert_eq(@markdown.validate_link(@markdown.normalize_link("a%2fb%zz")), true)
  assert_eq(@markdown.normalize_link("/路径 x"), "/%E8%B7%AF%E5%BE%84%20x")
  assert_eq(@markdown.normalize_link_text("/路径 x"), "/路径 x")
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("/路径 x")),
    true,
  )
  assert_eq(
    @markdown.normalize_link("http://a.com/😀"),
    "http://a.com/%F0%9F%98%80",
  )
  assert_eq(
    @markdown.normalize_link_text("http://a.com/😀"),
    "http://a.com/😀",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("http://a.com/😀")),
    true,
  )
  assert_eq(
    @markdown.normalize_link(" javascript:alert(1)"),
    "javascript:alert(1)",
  )
  assert_eq(
    @markdown.normalize_link_text(" javascript:alert(1)"),
    "javascript:alert(1)",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link(" javascript:alert(1)")),
    false,
  )
  assert_eq(
    @markdown.normalize_link("data:image/png;base64,AAA"),
    "data:image/png;base64,AAA",
  )
  assert_eq(
    @markdown.normalize_link_text("data:image/png;base64,AAA"),
    "data:image/png;base64,AAA",
  )
  assert_eq(
    @markdown.validate_link(
      @markdown.normalize_link("data:image/png;base64,AAA"),
    ),
    true,
  )
  assert_eq(@markdown.normalize_link("DATA:text/html,x"), "DATA:text/html,x")
  assert_eq(
    @markdown.normalize_link_text("DATA:text/html,x"),
    "DATA:text/html,x",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("DATA:text/html,x")),
    false,
  )
  assert_eq(
    @markdown.normalize_link("file:///etc/passwd"),
    "file:///etc/passwd",
  )
  assert_eq(
    @markdown.normalize_link_text("file:///etc/passwd"),
    "file:///etc/passwd",
  )
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("file:///etc/passwd")),
    false,
  )
  assert_eq(@markdown.normalize_link("VBScript:x"), "VBScript:x")
  assert_eq(@markdown.normalize_link_text("VBScript:x"), "VBScript:x")
  assert_eq(
    @markdown.validate_link(@markdown.normalize_link("VBScript:x")),
    false,
  )
}
