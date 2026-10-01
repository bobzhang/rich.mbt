///|
/// Format the result of `literal_eval` like the oracle script does.
fn literal_eval_case(source : String) -> String {
  try literal_eval_impl(source) catch {
    LitSyntax(msg) => "SyntaxError " + msg
    LitValue(msg) => "ValueError " + msg
  } noraise {
    v => "OK " + v.repr()
  }
}
