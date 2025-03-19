///|
pub fn Seq::new[T](f : () -> (T, Seq[T])?) -> Seq[T] {
  f
}

///| Checks if the sequence is empty
pub fn Seq::is_empty[T](seq : Seq[T]) -> Bool {
  match (seq._)() {
    None => true
    Some(_) => false
  }
}

///|
pub fn Seq::default[T]() -> Seq[T] {
  Seq(fn() { None })
}

///| Unwrap a sequence
///
/// If `seq` is empty, then `seq.uncons()` is `None`  
/// Else is `Some(hd, tl)` where `hd` is the head of the sequence
/// and `tl` is the tail
pub fn Seq::uncons[T](seq : Seq[T]) -> (T, Seq[T])? {
  (seq._)()
}

///| Map the sequence
///
/// If the sequence is x0, x1, ... then `seq.map(f)` is f(x0), f(x1), ...
pub fn Seq::map[T1, T2](seq : Seq[T1], f : (T1) -> T2) -> Seq[T2] {
  Seq(fn() { seq.uncons().map(fn { (hd, tl) => (f(hd), tl.map(f)) }) })
}

///| Construct a sequence from list
pub fn Seq::from_list[T](list : @immut/list.T[T]) -> Seq[T] {
  Seq(fn() {
    match list {
      Nil => None
      Cons(hd, tl) => Some((hd, Seq::from_list(tl)))
    }
  })
}

///| Construct a sequence from string
pub fn Seq::from_string(str : String) -> Seq[Char] {
  fn aux(offset : Int) -> Seq[Char] {
    Seq(fn() -> (Char, Seq[Char])? {
      if offset >= str.length() {
        return None
      }
      let ch = str[offset]
      if ch.to_int() >= 0xd800 && ch.to_int() <= 0xdbff {
        let ch2 = str[offset + 1]
        Some(
          (
            Char::from_int(
              0x10000 + ((ch.to_int() - 0xd800) << 10) + ch2.to_int() - 0xdc00,
            ),
            aux(offset + 2),
          ),
        )
      } else {
        Some((ch, aux(offset + 1)))
      }
    })
  }

  aux(0)
}

///| Construct a sequence from array
pub fn Seq::from_array[T](array : ArrayView[T]) -> Seq[T] {
  Seq(fn() {
    match array {
      [] => None
      [hd, .. rest] => Some((hd, Seq::from_array(rest)))
    }
  })
}

///|
pub fn length[T](self : Seq[T]) -> Int {
  loop self.uncons(), 0 {
    None, cumul => cumul
    Some((_, tl)), cumul => continue tl.uncons(), cumul + 1
  }
}

///|
pub impl[T : Show] Show for Seq[T] with to_string(self) {
  loop self.uncons(), "" {
    None, cumul => cumul
    Some((hd, tl)), cumul => continue tl.uncons(), cumul + hd.to_string()
  }
}

///|
pub impl[T : Show] Show for Seq[T] with output(self, log) {
  loop self.uncons() {
    None => ()
    Some((hd, tl)) => {
      (hd as &Show).output(log)
      continue tl.uncons()
    }
  }
}
