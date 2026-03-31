# frozen_string_literal: true

require "bundler/setup"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "io/rm_page"
require "io/rmdoc_writer"
require "shapes/shapes"
require "shapes/shape_library"
require "shapes/png_shape_page_generator"
