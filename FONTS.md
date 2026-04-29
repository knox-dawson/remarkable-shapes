# Fonts

This project uses vector stroke fonts rendered through `Remarkable::LineFont`.

This project is licensed under MIT.

Included fonts are licensed separately under SIL Open Font License 1.1 and GNU GPLv2.

## Font Families

Current selectable font families:

- `line_font`
- `line_font_italic`
- `line_font_cursive`
- `line_font_mono`
- `noto_lines_mono`
- `noto_lines_mono_filled`
- `noto_lines_sans`
- `noto_lines_sans_filled`
- `noto_lines_sans_italic`
- `noto_lines_sans_italic_filled`
- `relief_singleline`
- `relief_singleline_italic`
- `relief_singleline_mono`

## YAML Usage

Use `font:` to select a family:

```yaml
objects:
  - type: text
    x: 170
    y: 240
    width: 1000
    height: 60
    text: "italic sample"
    size: 36
    stroke_width: 3
    font: line_font_italic
    color: black
```

Relief example:

```yaml
objects:
  - type: text
    x: 170
    y: 320
    width: 1000
    height: 60
    text: "Relief italic sample"
    size: 36
    stroke_width: 3
    font: relief_singleline_italic
    color: black
```

## Ruby Usage

```ruby
Remarkable::Shapes.text(
  page,
  "Hello",
  170,
  240,
  size: 36,
  stroke_width: 3,
  font: :line_font_italic
)
```

## Relief SingleLine (Modified)

Original font:
https://github.com/isdat-type/Relief-SingleLine

License:
SIL Open Font License, Version 1.1

This font has been modified from the original version.

Modifications:
- added italics version
- added monospaced version

The font software is licensed under the SIL Open Font License, Version 1.1.

## Lines Font (modified)

Original author:
qwert2003

Original project:
https://sourceforge.net/projects/drawj2d/

License:
GNU General Public License, version 2.0 (GPLv2)

This font has been modified from the original version.

Modifications:
- added italics version
- changed monospaced version
- shortened the hyphen

The font is distributed under the GPLv2.

## Noto Mono and Sans

Original font:
https://fonts.google.com/noto/specimen/Noto+Sans

License:
SIL Open Font License, Version 1.1

This font has been converted from TrueType outlines into line-font JSON.

Included variants:
- `noto_lines_mono`
- `noto_lines_mono_filled`
- `noto_lines_sans`
- `noto_lines_sans_filled`
- `noto_lines_sans_italic`
- `noto_lines_sans_italic_filled`
