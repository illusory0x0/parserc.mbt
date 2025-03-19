///| A possibility infinite lazy list
pub type Seq[T] () -> (T, Seq[T])?

///| A parser combinator
pub type Parser[Token, Value] (Seq[Token]) -> (Value, Seq[Token])?
