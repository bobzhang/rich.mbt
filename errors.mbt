// Port of rich/errors.py.

///|
/// Errors raised by Rich. Constructors mirror the upstream exception classes.
pub(all) suberror RichError {
  /// The style definition could not be parsed.
  StyleSyntaxError(String)
  /// No such style (theme lookup and parsing both failed).
  MissingStyle(String)
  /// Style stack is invalid.
  StyleStackError(String)
  /// Object is not renderable.
  NotRenderableError(String)
  /// Markup was badly formatted.
  MarkupError(String)
  /// Error related to Live display.
  LiveError(String)
  /// Alt screen mode was required.
  NoAltScreen(String)
  /// Writing to the console file failed.
  WriteError(String)
  /// No emoji by that name (upstream `emoji.NoEmoji`).
  NoEmoji(String)
  /// An invalid argument (upstream `ValueError`/`TypeError`).
  ValueError(String)
} derive(Debug)

///|
pub impl Show for RichError with fn output(self, logger) {
  let message = match self {
    StyleSyntaxError(m)
    | MissingStyle(m)
    | StyleStackError(m)
    | NotRenderableError(m)
    | MarkupError(m)
    | LiveError(m)
    | NoAltScreen(m)
    | WriteError(m)
    | NoEmoji(m)
    | ValueError(m) => m
  }
  logger.write_string(message)
}
