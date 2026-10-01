///|
test "replace" {
  inspect(@emoji.replace("my code is :smiley:"), content="my code is 😃")
  inspect(@emoji.replace(":thumbs_up: :nope:"), content="👍 :nope:")
  inspect(
    @emoji.replace(":smiley-text:").escape(),
    content=(
      #|"😃︎"
    ),
  )
  inspect(
    @emoji.replace(":smiley:", default_variant="emoji").escape(),
    content=(
      #|"😃️"
    ),
  )
  // names are lower-cased with Python's (Unicode) `str.lower`
  inspect(@emoji.replace(":CURAÇAO: :Smiley:"), content="🇨🇼 😃")
}
