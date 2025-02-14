///| A parser combinator
pub type Parser[Token, Value] (Seq[Token]) -> (Value, Seq[Token])?

///| Parses a sequence of tokens
///
/// If the parsing succeeds, `Some(result, rest)` is returned  
/// Otherwise, `None` is returned.
/// TODO: Move to `Result[A, B]`
pub fn Parser::parse[Token, Value](
  self : Parser[Token, Value],
  sequence : Seq[Token]
) -> (Value, Seq[Token])? {
  (self._)(sequence)
}

///| Parses a token with predicate
///
/// The predicate should return `Some(value)` if the tokens fulfills
/// or `None` otherwise
pub fn pvalue[Token, Value](
  predicate : (Token) -> Value?
) -> Parser[Token, Value] {
  Parser(fn(seq) {
    let (hd, rest) = match seq.uncons() {
      Some(s) => s
      None => return None
    }
    let value = match predicate(hd) {
      Some(s) => s
      None => return None
    }
    Some((value, rest))
  })
}

///| Parser that always fail
pub fn pfail[Token, A]() -> Parser[Token, A] {
  Parser(fn(_tokens) { None })
}

///| Parser that always succeed with given value
pub fn pconst[Token, A](a : A) -> Parser[Token, A] {
  Parser(fn(tokens) { Some((a, tokens)) })
}

///|
pub fn lift2[Token, A, B, C](
  f : (A, B) -> C
) -> (Parser[Token, A], Parser[Token, B]) -> Parser[Token, C] {
  fn(pa, pb) { pa.apply(pb.apply(pconst(fn(b) { fn(a) { f(a, b) } }))) }
}

///|
pub fn sequence[Token, A](
  parsers : Array[Parser[Token, A]]
) -> Parser[Token, Array[A]] {
  Parser(fn(tokens) {
    let result : Array[A] = []
    let mut tokens = @option.some(tokens)
    parsers.each(fn(parser) {
      match tokens {
        Some(ts) =>
          tokens = parser
            .parse(ts)
            .map(fn {
              (hd, tl) => {
                result.push(hd)
                tl
              }
            })
        None => ()
      }
    })
    tokens.map(fn(tokens) { (result, tokens) })
  })
}

test "sequence" {
  let parser = sequence([pchar('a'), pchar('b'), pchar('c')])
  inspect!(
    parser.parse(Seq::from_string("abc")),
    content="Some((['a', 'b', 'c'], ))",
  )
  inspect!(parser.parse(Seq::from_string("ab")), content="None")
}

///|
pub fn Parser::and_then[Token, A, B](
  self : Parser[Token, A],
  other : Parser[Token, B]
) -> Parser[Token, (A, B)] {
  Parser(fn(tokens) {
    let (a, rest) = match self.parse(tokens) {
      None => return None
      Some(s) => s
    }
    let (b, rest2) = match other.parse(rest) {
      None => return None
      Some(s) => s
    }
    Some(((a, b), rest2))
  })
}

///|
pub fn Parser::or_else[Token, A](
  self : Parser[Token, A],
  other : Parser[Token, A]
) -> Parser[Token, A] {
  Parser(fn(tokens) {
    match self.parse(tokens) {
      None => other.parse(tokens)
      Some(_) as result => result
    }
  })
}

///|
pub fn Parser::or_others[Token, A](
  self : Parser[Token, A],
  others : ArrayView[Parser[Token, A]]
) -> Parser[Token, A] {
  match others {
    [] => self
    [hd, .. tl] => self.or_else(hd.or_others(tl))
  }
}

///|
pub fn Parser::map[Token, A, B](
  self : Parser[Token, A],
  f : (A) -> B
) -> Parser[Token, B] {
  Parser(fn(tokens) {
    let (a, rest) = match self.parse(tokens) {
      None => return None
      Some(s) => s
    }
    Some((f(a), rest))
  })
}

///|
pub fn Parser::apply[Token, A, B](
  self : Parser[Token, A],
  f : Parser[Token, (A) -> B]
) -> Parser[Token, B] {
  self.and_then(f).map(fn(pair) { (pair.1)(pair.0) })
}

///|
pub fn Parser::repeat_n[Token, A](
  self : Parser[Token, A],
  n : Int
) -> Parser[Token, Array[A]] {
  self.repeat_n_with_sep(n, pconst(()))
}

///|
pub fn Parser::repeat_n_with_sep[Token, A, B](
  self : Parser[Token, A],
  n : Int,
  sep : Parser[Token, B]
) -> Parser[Token, Array[A]] {
  if n < 0 {
    pfail()
  } else if n == 0 {
    pconst([])
  } else if n == 1 {
    self.map(fn(v) { Array::make(1, v) })
  } else {
    Parser(fn(seq) {
      let (hd, tl) = match self.parse(seq) {
        None => return None
        Some(s) => s
      }
      let array = Array::make(n, hd)
      let parser = sep.and_then(self).omit_first()
      for i = 0, rest = tl; i < n - 1; {
        let (hd, tl) = match parser.parse(rest) {
          None => return None
          Some(s) => s
        }
        array[i + 1] = hd
        continue i + 1, tl
      } else {
        Some((array, rest))
      }
    })
  }
}

///|
pub fn Parser::repeat_0_to_n[Token, A](
  self : Parser[Token, A],
  n : Int
) -> Parser[Token, Array[A]] {
  self.repeat_0_to_n_with_sep(n, pconst(()))
}

///|
pub fn Parser::repeat_0_to_n_with_sep[Token, A, B](
  self : Parser[Token, A],
  n : Int,
  separator : Parser[Token, B]
) -> Parser[Token, Array[A]] {
  if n < 0 {
    pfail()
  } else if n == 0 {
    pconst([])
  } else {
    Parser(fn(seq) {
      let sep_self = separator.and_then(self).omit_first()
      match self.parse(seq) {
        None => return Some(([], seq))
        Some((hd, tl)) => {
          let result = [hd]
          for i = 0, rest = tl; i < n - 1; {
            match sep_self.parse(rest) {
              Some((hd, tl)) => {
                result.push(hd)
                continue i + 1, tl
              }
              None => break Some((result, rest))
            }
          } else {
            Some((result, rest))
          }
        }
      }
    })
  }
}

///|
pub fn Parser::repeat[Token, A](
  self : Parser[Token, A]
) -> Parser[Token, Array[A]] {
  self.repeat_with_sep(pconst(()))
}

///|
pub fn Parser::repeat_with_sep[Token, A, B](
  self : Parser[Token, A],
  separator : Parser[Token, B]
) -> Parser[Token, Array[A]] {
  Parser(fn(seq) {
    let sep_self = separator.and_then(self).omit_first()
    match self.parse(seq) {
      None => return Some(([], seq))
      Some((hd, tl)) => {
        let result = [hd]
        let input = loop tl {
          input =>
            match sep_self.parse(input) {
              Some((hd, tl)) => {
                result.push(hd)
                continue tl
              }
              None => input
            }
        }
        Some((result, input))
      }
    }
  })
}

test "repeat" {
  let parser = pvalue(fn {
    '0' => Some(0)
    '1' => Some(1)
    _ => None
  })
  let repeat_n = parser.repeat_n(3)
  inspect!(
    repeat_n.parse(Seq::from_string("0110")),
    content="Some(([0, 1, 1], '0'))",
  )
  let repeat_0_to_n = parser.repeat_0_to_n(3)
  inspect!(
    repeat_0_to_n.parse(Seq::from_string("0110")),
    content="Some(([0, 1, 1], '0'))",
  )
  inspect!(
    repeat_0_to_n.parse(Seq::from_string("01210")),
    content="Some(([0, 1], '2''1''0'))",
  )
  inspect!(
    repeat_0_to_n.parse(Seq::from_string("2")),
    content="Some(([], '2'))",
  )
  let repeat = parser.repeat()
  inspect!(
    repeat.parse(Seq::from_string("0110")),
    content="Some(([0, 1, 1, 0], ))",
  )
}

///|
pub fn Parser::optional[Token, A](self : Parser[Token, A]) -> Parser[Token, A?] {
  self.map(@option.some).or_else(pconst(Option::None))
}

///|
pub fn Parser::omit_first[Token, A, B](
  parser : Parser[Token, (A, B)]
) -> Parser[Token, B] {
  parser.map(fn(pair) { pair.1 })
}

///|
pub fn Parser::omit_second[Token, A, B](
  parser : Parser[Token, (A, B)]
) -> Parser[Token, A] {
  parser.map(fn(pair) { pair.0 })
}

///|
pub fn Parser::between[Token, A, B](
  self : Parser[Token, A],
  around : Parser[Token, B]
) -> Parser[Token, A] {
  around.and_then(self).omit_first().and_then(around).omit_second()
}

///|
pub fn Parser::ref[Token, A](self : Ref[Parser[Token, A]]) -> Parser[Token, A] {
  Parser(fn(str) { self.val.parse(str) })
}

// String specific parsers
///|
pub fn pchar_such_that(predicate : (Char) -> Bool) -> Parser[Char, Char] {
  pvalue(fn { char => @option.when(predicate(char), fn() { char }) })
}

///|
pub fn pchar(char : Char) -> Parser[Char, Char] {
  pchar_such_that(fn(c) { c == char })
}

///| parse digit
///
/// %x30-39
pub let pdigit : Parser[Char, Int] = one_of([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])

///|
pub fn one_of[A : Show](array : Array[A]) -> Parser[Char, A] {
  array.rev_fold(
    fn(p, i) { pstring(i.to_string()).map(fn(_str) { i }).or_else(p) },
    init=pfail(),
  )
}

///|
let pdigits : Parser[Char, (Char?, (Int, Array[Int]))] = pchar('-')
  .optional()
  .and_then(
    pchar('0')
    .map(fn(_ch) { (0, []) })
    .or_else(
      pvalue(fn {
        '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' as char =>
          Some(char.to_int() - 0x30)
        _ => None
      }).and_then(pdigit.repeat()),
    ),
  )

///| parser for integer
///
/// [ "-" ] ( %x30 / (%x31-39) *(%x30-39)
pub let pint : Parser[Char, Int] = pdigits.map(fn(tuple) {
  let sign = tuple.0
  let digits = tuple.1
  let i = digits.1.fold(fn(a, b) { 10 * a + b }, init=digits.0)
  match sign {
    Some(_) => -i
    None => i
  }
})

///| parser for integer 64 bits
///
/// [ "-" ] ( %x30 / (%x31-39) *(%x30-39)
pub let pint64 : Parser[Char, Int64] = pdigits.map(fn(tuple) {
  let sign = tuple.0
  let digits = tuple.1
  let i = digits.1.fold(
    fn(a, b) { 10L * a + b.to_int64() },
    init=digits.0.to_int64(),
  )
  match sign {
    Some(_) => -i
    None => i
  }
})

test "pint" {
  inspect!(pint.parse(Seq::from_string("12345")), content="Some((12345, ))")
  inspect!(pint.parse(Seq::from_string("-0")), content="Some((0, ))")
  inspect!(pint.parse(Seq::from_string("0")), content="Some((0, ))")
  inspect!(pint.parse(Seq::from_string("-01")), content="Some((0, '1'))")
  inspect!(pint.parse(Seq::from_string("-100")), content="Some((-100, ))")
}

///| parser that tries to match the given string
pub fn pstring(string : String) -> Parser[Char, String] {
  Parser(fn(seq) {
    let iter = loop seq, Seq::from_string(string) {
      iter, input => {
        if not(input.is_empty()) {
          let (target, rest_target) = match input.uncons() {
            None => return None
            Some(s) => s
          }
          let (char, rest) = match iter.uncons() {
            None => return None
            Some(s) => s
          }
          if target != char {
            return None
          }
          continue rest, rest_target
        }
        break iter
      }
    }
    Some((string, iter))
  })
}

test "pstring" {
  let parser = pstring("asdf")
  inspect!(
    parser.parse(Seq::from_string("asdfjkl;")),
    content=
      #|Some(("asdf", 'j''k''l'';'))
    ,
  )
  inspect!(parser.parse(Seq::from_string("jkl;")), content="None")
}
