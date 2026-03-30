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
```

After `bundle install`, the same commands can be run with `bundle exec`.

Generate a local untracked shape file:

```bash
ruby bin/generate_shape local_shapes/post-it/example.rb out/example.rmdoc
ruby bin/generate_shape post-it/example out/example.rmdoc
```

Local shape files should evaluate to a callable object, such as:

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

No license has been selected yet. Add one before publishing the repository on GitHub.
