# Parser combinator

这是一个从 https://github.com/peter-jerry-ye/moonbit-parser-combinator fork 的项目

A simple parser combinator 简单的语法分析组合子

Support any stream with `Seq` 利用`Seq`支持各类流

## Usage 使用方法

```moonbit
test {
  let parser = pstring("Hello").and_then(pint)
  let Some(result, _) = parser.parse(Seq::from_string("Hello1234"))
  inspect(result, content="Hello")
}
```