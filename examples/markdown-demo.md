# remarkable-shapes markdown supports these markdown features

remarkable-shapes can turn markdown into reMarkable pages. This demo walks through the elements and styles that the current renderer supports.

## Paragraphs

This is a normal paragraph. It should wrap, use the body style, and read naturally. It also keeps apostrophes like it's and other everyday punctuation.

Another body paragraph shows the spacing between paragraphs.

This paragraph includes inline code like `code span` so you can see the monospace style inside normal text.

This paragraph shows *italic*, **bold**, and ***bold italic*** inline emphasis.

## Heading levels

### Heading level 3

#### Heading level 4

##### Heading level 5

###### Heading level 6

## Blockquotes

> Blockquotes use the configured blockquote style.
> They are useful for notes, callouts, and quoted text.

## Unordered lists

- First bullet
- Second bullet
  - Nested bullet
  - Another nested bullet
- Third bullet

## Ordered lists

1. First item
2. Second item
   1. Nested item
   2. Another nested item
3. Third item

## Code block

```ruby
puts "remarkable-shapes markdown demo"
puts "This code block uses the monospace style."
```

---

That horizontal rule above is the thematic break element.

If you want to render this demo, use `bin/generate_markdown_book` with `examples/markdown-demo.md`.
