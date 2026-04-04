# remarkable-shapes

Tools for generating uploadable `.rmdoc` files for reMarkable tablets.

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
bin/generate_image --input examples/cat.png --output out/cat-image.rmdoc
```

Generate a page from a YAML description:

```bash
bin/generate_yaml --yaml examples/basic-shapes.yml --output out/basic-shapes.rmdoc
```

Generate a page from a Ruby shape file (lambda):

```bash
bin/generate_shape --shape examples/us-flag.rb --output out/us-flag.rmdoc
```

Generate YAML pages from a directory of PNGs:

```bash
bin/generate_yaml_pages --image-dir emoji --layout 3x5 --output-dir examples/emoji-pages --prefix emoji --outer-padding 40 --cell-gap 30 --pixel-gap -0.10
```

Built-in sample pages can live as either YAML or Ruby shape files in `examples/`, for example:

```bash
bin/generate_yaml --yaml examples/shape-sampler.yml --output out/shape-sampler.rmdoc
bin/generate_shape --shape examples/us-flag.rb --output out/us-flag.rmdoc
```

## Wiki

More documentation can be found in the [Wiki](https://github.com/knox-dawson/remarkable-shapes/wiki).

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
