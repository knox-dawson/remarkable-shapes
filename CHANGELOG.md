# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
