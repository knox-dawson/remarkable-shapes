# remarkable-shapes

Ruby tools for generating uploadable `.rmdoc` files for reMarkable tablets.

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
