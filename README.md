# remarkable-shapes

Ruby tools for generating uploadable `.rmdoc` files for reMarkable tablets.

Current version: `0.9.0-beta.2`

## Installation

Prerequisites:

- Ruby
- Bundler

If `bundle` is not already available, install Bundler with:

```bash
gem install bundler
```

Setup:

```bash
cd remarkable-shapes
bundle install
```

## Usage

Generate a one-off image page from a PNG:

```bash
ruby bin/generate_image examples/cat.png out/cat-image.rmdoc
```

Generate a page from a YAML description:

```bash
ruby bin/generate_yaml examples/basic-shapes.yml out/basic-shapes.rmdoc
```

Generate a page from a Ruby lambda:

```bash
ruby bin/generate_shape examples/us-flag.rb out/us-flag.rmdoc
```

Generate YAML pages from a directory of PNGs:

```bash
ruby bin/generate_yaml_pages emoji 3x5 examples/emoji-pages emoji 40 30 -0.10
```

Built-in sample pages can live as either YAML or Ruby lambda files in `examples/`, for example:

```bash
ruby bin/generate_yaml examples/shape-sampler.yml out/shape-sampler.rmdoc
ruby bin/generate_shape examples/us-flag.rb out/us-flag.rmdoc
```

After `bundle install`, the same commands can be run with `bundle exec`.

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
