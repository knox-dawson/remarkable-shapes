# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.9.0-beta.2] - 2026-04-02

### Changed

- Added `bin/generate_yaml_pages` to generate YAML page descriptions from directories of PNG files.
- Extended the YAML renderer with additional shape primitives used by migrated examples.
- Restored `bin/generate_shape` as a generic external lambda runner without built-in shape-library routines.
- Mixed the example set to support both YAML files and Ruby lambda files where each format is more practical.

### Added

- Added YAML example pages for shape samplers, color samplers, flags, line-font samples, and image-backed examples.
- Added a Ruby lambda example for `us-flag`.
- Added test coverage for the YAML page generator workflow.

### Removed

- Removed the old built-in Ruby shape library entrypoints and the Ruby code generator for PNG page batches.

## [0.9.0-beta.1] - 2026-04-02

### Added

- Initial development release.
