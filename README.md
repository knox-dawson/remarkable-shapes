# remarkable-shapes

Ruby tools for generating uploadable `.rmdoc` files for reMarkable tablets.

## Overview

This project generates uploadable `.rmdoc` files and includes its own `.rm` and `.rmdoc` writing logic.

The code is organized into:

- `lib/io`
  low-level lines v6 and `.rmdoc` writers
- `lib/shapes`
  reusable geometry helpers and named output shapes
- `bin/generate_shape`
  command-line shape generator
- `examples`
  tracked example inputs and generated page definitions
- `spec`
  RSpec tests for page construction and `.rmdoc` writing

## Installation

```bash
cd remarkable-shapes
bundle install
```

## Usage

List available shapes:

```bash
ruby bin/generate_shape --help
```

Generate sample outputs:

```bash
ruby bin/generate_shape shape-sampler out/shape-sampler.rmdoc
ruby bin/generate_shape color-sampler out/color-sampler.rmdoc
ruby bin/generate_shape us-flag out/us-flag.rmdoc
ruby bin/generate_shape greenland-flag out/greenland-flag.rmdoc
ruby bin/generate_shape cat-png out/cat-png.rmdoc
ruby bin/generate_shape line-font-sampler out/line-font-sampler.rmdoc
```

After `bundle install`, the same commands can be run with `bundle exec`.

For your own shape projects, the cleanest setup is a separate repo checked out beside this one, then point `generate_shape` at it with `REMARKABLE_SHAPES_PATH` or an explicit file path. Keep `remarkable-shapes` as the reusable engine repo, and keep your project-specific shape files in that separate tracked repo.

Generate tracked example page files from a directory of PNGs:

```bash
ruby bin/generate_png_shape_pages emoji 3x5 examples/emoji-pages emoji
```

With explicit inner padding, cell spacing, and slight pixel overlap:

```bash
ruby bin/generate_png_shape_pages emoji 3x5 examples/emoji-pages emoji 40 30 -0.10
```

Generate page files in an external shapes repo:

```bash
ruby bin/generate_png_shape_pages emoji 3x5 ../remarkable-shape-projects/emoji-pages emoji
```

Then render one of the generated pages:

```bash
ruby bin/generate_shape examples/emoji-pages/emoji-01.rb out/emoji-01.rmdoc
```

Render a shape from your external shapes repo:

```bash
REMARKABLE_SHAPES_PATH=../remarkable-shape-projects ruby bin/generate_shape post-it/example out/example.rmdoc
ruby bin/generate_shape ../remarkable-shape-projects/post-it/example.rb out/example.rmdoc
```

Shape files should evaluate to a callable object, such as:

```ruby
lambda do |page|
  Remarkable::Shapes.rm2_box(page)
end
```

## API Notes

The drawing helpers in `lib/shapes/shapes.rb` follow a normalized pattern:

- `page` first
- geometric parameters next
- `rgba:`
- `color:`
- `brush:`

By default, methods draw in RGBA mode using opaque black and the fineliner brush. Passing a tablet colour code through `color:` switches the stroke to one of the built-in palette values.

## Development

Run the test suite:

```bash
bundle exec rspec
```

Generate YARD docs:

```bash
bundle exec yard doc
```

## License

This project is licensed under the MIT License.
See the [LICENSE](LICENSE) file for details.
