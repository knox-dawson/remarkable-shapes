# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.9.0-beta.6] - 2026-04-20

### Added

- Added inline markdown emphasis support for `*italic*`, `**bold**`, and nested bold-italic runs in `bin/generate_markdown_book`.
- Added PNG downsampling support for image rendering, with `downsample: 2` averaging each 2x2 block, `downsample: 3` averaging each 3x3 block, and so on.
- Added new font: relief_singleline_mono

### Changed

- Rendered new version of font: line_font_mono
- Tuned monospaced font widths and centering

## [0.9.0-beta.5] - 2026-04-07

### Added

- Added `bin/generate_yaml_book` for end-to-end multipage `.rmdoc` generation.
- Added a YAML page-list workflow that renders an ordered set of YAML layouts into per-page `.rmdoc` files, writes an `rmcat` script, and can build the final multipage `.rmdoc`.
- Added a cover/template/items workflow for multipage generation, including support for `--cover-yaml`, `--template-yaml`, `--items-yaml`, and `--image-dir`.
- Added template-driven page generation with `template` blocks and grid-driven `cell: auto` placement so multiple objects for one item can share the same assigned cell.
- Added saved `rmcat` script generation plus optional automatic concatenation when `rmcat` (https://github.com/kg4zow/rm2-scripts/tree/main/rmcat/) is available.
- Added PNG-backed YAML shape objects for circles and rectangles, including `circle_png_fill`, `circle_png_outline_fill`, `rectangle_png_fill`, and `rectangle_png_outline_fill`.
- Added generated RGBA-grid helpers for rasterizing filled circles and rectangles with antialiasing for the new PNG-backed shape workflow.
- Added selectable line-font families through `font:` for both the Ruby text helpers and YAML `text` / `shadow_text` objects.
- Added explicit `line_font` as an alias for the built-in default line-font family.
- Added a generated `line_font_italic` family by slanting the built-in plain glyphs into a synthetic italic stroke font.
- Added flattened built-in `line_font_cursive` and `line_font_mono` families so cursive and monospaced variants can be selected directly through `font:`.
- Added a converted `relief_singleline` stroke-font family under `data/relief_singleline`.
- Added a generated `relief_singleline_italic` family by slanting the imported Relief SingleLine plain glyphs into a synthetic italic stroke font.
- Added `bin/ufo_to_line_font` to convert a simple UFO source into the line-font JSON stroke format used by the renderer.
- Added `bin/line_font_to_mono` to generate monospaced stroke-font JSON from any imported Hershey-style font data.
- Added a converted `relief_singleline_mono` stroke-font family under `data/relief_singleline_mono`.
- Added `examples/font-family-sampler.yml`, `examples/font-comparison-sampler.yml`, and `examples/relief-line-font-sampler.yml` plus their generated `out/` samples.
- Added `bin/generate_font_samples` to build one full-coverage sample page per font family and render the matching `.rmdoc` outputs.
- Added `bin/generate_markdown_book` to parse markdown through `kramdown`, generate intermediate YAML pages, and build a multipage `.rmdoc` book through the existing YAML book pipeline.
- Added a default markdown rendering config at `config/markdown_defaults.yml` plus support for partial user config overrides and `--dump-default-config`.
- Added temporary compatibility so older `style` and `mono` text options still map onto the new flattened font families during the beta.5 transition, with `style: italic` now pointing at the synthetic `line_font_italic` family and `style: cursive` pointing at the true cursive family.

### Changed

- Changed the template workflow so page capacity comes from the template canvas grid instead of separate `slots` definitions.
- Changed box-capable YAML objects so when neither `cell` nor `x`, `y`, `width`, and `height` are given, the object box defaults to the full canvas.
- Changed grid cell placement to allow multiple objects to share the same cell, which supports item templates like an image and label in one cell with different placement values.
- Changed circle rendering and constant-width segment helpers to write explicit `thickness_scale` values derived from the requested width, improving downstream export behavior for wide strokes.
- Changed PNG outline-fill objects so the fill is rasterized through the image path while outlines continue to use the normal vector line rendering.
- Changed aspect-ratio-preserving box placement so square-fit shapes, fitted images, and nested YAML honor `placement` when there is extra space inside an explicit box.
- Changed line-font family discovery so `data/line_font` now contains only the plain built-in family, while additional families such as `line_font_italic`, `line_font_cursive`, `line_font_mono`, `relief_singleline`, and `relief_singleline_italic` are loaded directly from sibling directories under `data/`.
- Changed the generated synthetic italic line-fonts to use tighter advance widths and pair-specific spacing adjustments for improved visual spacing.
- Changed the generated per-font sample pages to render larger, darker sample text while filtering out invisible escaped codepoint keys from the displayed character set.
- Changed the multipage book tooling so markdown can now be converted into paginated YAML `text` and `line` objects before final `.rmdoc` concatenation, including a first-pass fenced-code-block normalization step.

## [0.9.0-beta.4] - 2026-04-07

### Added

- Added percentage-based YAML grid track sizing through `row_sizes` and `column_sizes`, while preserving `rows` and `cols` as the count-based grid definition.
- Added YAML grid annotations that can draw borders around every cell and label each cell with its `x`, `y`, `w`, and `h` values, with configurable border and text styling plus `annotations.show` for toggling the overlay.
- Added named box-based right-triangle directions (`upper-left`, `upper-right`, `lower-left`, `lower-right`) so the 90-degree corner can be selected without using raw rotation values.
- Improved default image rendering with `pixel_gap: -3.0` and `type: image` using `highlighter_2` by default

### Fixed

- Fixed box-based triangle layout in YAML grid cells so rotated triangle outlines are fitted back into their target cell boxes instead of extending outside the cell after rotation.
- Fixed box-based triangle fills in the YAML renderer so `right_triangle_*` objects use the right-triangle fill construction and `isosceles_triangle_*` objects use the correct apex and base points for their fill geometry.

## [0.9.0-beta.3] - 2026-04-06

### Changed

- Updated `bin/generate_shape` and `bin/generate_yaml` so relative `--output` paths are rooted to the resolved external shapes-library path when `--input` is resolved through `REMARKABLE_SHAPES_PATH` or `--shapes-path`.
- Expanded the YAML object system with new geometry options, including `point_count` for stars, center-and-radius support for circles and semicircles, box-based triangle placement, triangle outline and outline-fill variants, regular polygon outline-fill, and broader `rotation` and `direction` handling.
- Added canvas `margin` plus cell-based grid layout support in YAML, including `grid`, `cell_padding`, `gutter`, per-cell borders, object `cell` placement, and default wrapping for text placed in grid cells.
- Reworked the `simple-shapes-grid` example to use the new grid system instead of fully manual coordinates.
- Updated the YAML object inventory and related wiki pages to reflect the expanded object set and the new grid layout workflow.
- Removed the embedded release version string from the text-and-image example text so it no longer needs to be updated for each release.

### Added

- Added support for the full current pen constant set in `Remarkable::RmPage::Pen`, including ballpoint, marker, paintbrush, mechanical pencil, eraser, calligraphy, and both v1 and v2 tool variants.
- Added a local `RmPage` spec suite covering the emitted v6 header, block order, point payload encoding, scene-space coordinates, and conditional RGBA tagging without requiring external reader dependencies.
- Added a user-facing `YAML Object Inventory` wiki guide describing the available YAML objects, their options, and practical usage.

### Fixed

- Repaired the converted `p-4u-wgro*` and `p-4u-ygpb*` shape-library files by regenerating them from the original parameter sources so the missing variables and shifted geometry logic match the source layouts again.
- Verified that all `post-it` shapes in the external library render cleanly after the conversion fixes.

## [0.9.0-beta.2] - 2026-04-04

### Changed

- Added `bin/generate_yaml_pages` to generate YAML page descriptions from directories of PNG files.
- Extended the YAML renderer with additional shape primitives used by migrated examples.
- Restored `bin/generate_shape` as a generic external lambda runner without built-in shape-library routines.
- Mixed the example set to support both YAML files and Ruby lambda files where each format is more practical.
- Converted all `bin/` commands to named `slop`-based option parsing and updated the README and wiki examples to match.
- Normalized `bin/generate_shape` and `bin/generate_yaml` to use `--input` and aligned their command examples accordingly.
- Extended `bin/generate_yaml` to resolve example names through `examples/`, `REMARKABLE_SHAPES_PATH`, and `--shapes-path`, matching `bin/generate_shape`.
- Added cut-and-paste YARD examples for the main Ruby lambda drawing helpers and YAML object renderer methods.
- Removed the temporary YAML image-object `gap` synonym so image spacing now uses `pixel_gap` consistently.

### Added

- Added YAML example pages for shape samplers, color samplers, flags, line-font samples, and image-backed examples.
- Added a Ruby lambda example for `us-flag`.
- Added test coverage for the YAML page generator workflow.
- Added the `slop` gem as a runtime dependency for command-line option parsing.

### Removed

- Removed the old built-in Ruby shape library entrypoints and the Ruby code generator for PNG page batches.

## [0.9.0-beta.1] - 2026-04-02

### Added

- Initial development release.
