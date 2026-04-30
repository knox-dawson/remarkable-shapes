# remarkable-shapes

Tools for generating uploadable `.rmdoc` files for reMarkable tablets.

Current version: `0.9.0-beta.7`

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

Note that `bundle install` should install gems (and dependencies) listed in the Gemfile, e.g., `slop`, `chunky_png`, etc.

This project has not been tested with Ruby versions prior to ruby 3.4.4.

## Usage

Generate a one-off image page from a PNG:

```bash
bin/generate_image --input examples/cat.png --downsample 2 --output out/cat-image.rmdoc
```

Generate a page from a YAML description:

```bash
bin/generate_yaml --input examples/basic-shapes.yml --output out/basic-shapes.rmdoc
```

Generate a page from a Ruby shape file (lambda):

```bash
bin/generate_shape --input examples/us-flag.rb --output out/us-flag.rmdoc
```

For `bin/generate_shape` and `bin/generate_yaml`, relative `--output` paths are normally relative to your current working directory. If `--input` is resolved through an external library root from `REMARKABLE_SHAPES_PATH` or `--shapes-path`, then a relative `--output` path is rooted to that same external library root.

Example:

```bash
REMARKABLE_SHAPES_PATH=/path/to/remarkable-shapes-library \
bin/generate_shape \
  --input post-it/p-4u-wgro-m-01.rb \
  --output post-it/out/p-4u-wgro-m-01.rmdoc
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

## Acknowledgements

This project was developed with reference to the following open source projects:

- librm_lines and pylibrm_lines by RedTTGMoss
- rmscene by Rick Lupton
- Drawj2d by qwert2003

These projects were extremely helpful in understanding the structure of reMarkable `.lines` and `.rm` files.

## License

This project is licensed under the MIT License.
See the [LICENSE](LICENSE) file for details.
