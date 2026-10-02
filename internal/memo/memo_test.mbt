///|
test "memo evicts the oldest entry when full" {
  let m : @memo.Memo[String, Int] = @memo.Memo::new(2)
  m.set("a", 1)
  m.set("b", 2)
  m.set("a", 10)
  inspect(m.length(), content="2")
  m.set("c", 3)
  inspect(m.length(), content="2")
  debug_inspect(m.get("a"), content="None")
  debug_inspect(m.get("b"), content="Some(2)")
  debug_inspect(m.get("c"), content="Some(3)")
  m.clear()
  inspect(m.length(), content="0")
}
