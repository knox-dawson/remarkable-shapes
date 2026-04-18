# frozen_string_literal: true

require "psych"

require_relative "../io/rm_page"
require_relative "shapes"
require_relative "line_font"

module Remarkable
  # Renders a simple user-facing YAML page description into reMarkable lines.
  module YamlShapeRenderer
    # Named physical tablet canvas presets.
    TABLETS = {
      "rm2" => { width: 1404.0, height: 1872.0 },
      "rmpro" => { width: 1620.0, height: 2160.0 }
    }.freeze

    # Default tablet preset when none is provided.
    DEFAULT_TABLET = "rm2"
    # Default canvas width used when none is provided.
    DEFAULT_CANVAS_WIDTH = TABLETS.fetch(DEFAULT_TABLET).fetch(:width)
    # Default canvas height used when none is provided.
    DEFAULT_CANVAS_HEIGHT = TABLETS.fetch(DEFAULT_TABLET).fetch(:height)
    # Default placement for the user canvas.
    DEFAULT_PLACEMENT = "center"
    # Default stroke width for outline objects.
    DEFAULT_STROKE_WIDTH = 4.0
    # Default cell padding for grid layouts.
    DEFAULT_CELL_PADDING = 0.0
    # Default gutter for grid layouts.
    DEFAULT_GUTTER = 0.0
    # Default annotation border stroke width.
    DEFAULT_ANNOTATION_BORDER_STROKE_WIDTH = 4.0
    # Default annotation border color.
    DEFAULT_ANNOTATION_BORDER_COLOR = "black"
    # Default annotation text size.
    DEFAULT_ANNOTATION_TEXT_SIZE = 18.0
    # Default annotation text stroke width.
    DEFAULT_ANNOTATION_TEXT_STROKE_WIDTH = 2.0
    # Default annotation text color.
    DEFAULT_ANNOTATION_TEXT_COLOR = "grey"
    # Default annotation text padding.
    DEFAULT_ANNOTATION_TEXT_PADDING = 8.0
    # Default brush for image objects.
    DEFAULT_IMAGE_BRUSH = RmPage::Pen::HIGHLIGHTER_2

    module_function

    # Loads a YAML file and renders it onto the page.
    #
    # @param page [Remarkable::RmPage]
    # @param yaml_path [String]
    # @example YAML file
    #   canvas:
    #     tablet: rm2
    #   objects:
    #     - type: rectangle_outline
    #       x: 130
    #       y: 130
    #       width: 1140
    #       height: 1610
    #       stroke_width: 4
    #       color: black
    # @return [Hash] resolved canvas layout
    def render_file(page, yaml_path)
      config = load_file_config(yaml_path)
      render(page, config, base_dir: File.dirname(File.expand_path(yaml_path)))
    end

    # Loads and normalizes a YAML config file.
    #
    # @param yaml_path [String]
    # @return [Hash]
    def load_file_config(yaml_path)
      config = Psych.safe_load(File.read(yaml_path), permitted_classes: [], aliases: false) || {}
      stringify_keys(config)
    end

    # Renders a YAML-derived configuration hash onto the page.
    #
    # @param page [Remarkable::RmPage]
    # @param config [Hash]
    # @param base_dir [String]
    # @param layout_override [Hash, nil]
    # @return [Hash] resolved canvas layout
    def render(page, config, base_dir: nil, layout_override: nil)
      base_dir ||= Dir.pwd
      canvas = stringify_keys(config.fetch("canvas", {}))
      layout = layout_override || resolve_canvas_layout(canvas)
      objects = config.fetch("objects", [])
      raise ArgumentError, "objects must be an array" unless objects.is_a?(Array)

      draw_grid_borders(page, layout) unless layout[:grid] && layout[:grid][:annotations]
      used_cells = {}
      objects.each do |object|
        render_object(page, stringify_keys(object), layout, base_dir:, used_cells:)
      end
      draw_grid_annotations(page, layout)

      layout
    end

    # Resolves the physical tablet profile from canvas settings.
    #
    # @param canvas [Hash]
    # @return [Hash]
    def resolve_tablet_profile(canvas)
      tablet = (canvas["tablet"] || DEFAULT_TABLET).to_s
      profile = TABLETS[tablet]
      raise ArgumentError, "unsupported tablet: #{tablet}" unless profile

      {
        tablet:,
        physical_width: profile.fetch(:width),
        physical_height: profile.fetch(:height)
      }
    end

    # Resolves the user canvas into standard page coordinates.
    #
    # @param canvas [Hash]
    # @return [Hash]
    def resolve_canvas_layout(canvas)
      profile = resolve_tablet_profile(canvas)
      width = (canvas["width"] || profile.fetch(:physical_width)).to_f
      height = (canvas["height"] || profile.fetch(:physical_height)).to_f
      raise ArgumentError, "canvas width must be positive" unless width.positive?
      raise ArgumentError, "canvas height must be positive" unless height.positive?

      placement = (canvas["placement"] || DEFAULT_PLACEMENT).to_s
      x = placement_x(placement, width, profile.fetch(:physical_width))
      y = placement_y(placement, height, profile.fetch(:physical_height))
      margin = fetch_number(canvas, "margin", 0.0)
      raise ArgumentError, "canvas margin must be non-negative" if margin.negative?

      content_x = x + margin
      content_y = y + margin
      content_width = width - (margin * 2.0)
      content_height = height - (margin * 2.0)
      raise ArgumentError, "canvas margin leaves no drawable width" unless content_width.positive?
      raise ArgumentError, "canvas margin leaves no drawable height" unless content_height.positive?

      grid = resolve_grid_layout(canvas["grid"], content_x, content_y, content_width, content_height)

      {
        x:,
        y:,
        width:,
        height:,
        content_x:,
        content_y:,
        content_width:,
        content_height:,
        margin:,
        grid:,
        placement:,
        tablet: profile.fetch(:tablet),
        physical_width: profile.fetch(:physical_width),
        physical_height: profile.fetch(:physical_height),
        scale: 1.0
      }
    end

    # Resolves an optional grid specification inside the canvas content area.
    #
    # @return [Hash, nil]
    def resolve_grid_layout(grid_value, x, y, width, height)
      return nil if grid_value.nil?

      rows, cols, options = parse_grid_definition(grid_value)
      cell_padding = fetch_number(options, "cell_padding", DEFAULT_CELL_PADDING)
      gutter = fetch_number(options, "gutter", DEFAULT_GUTTER)
      raise ArgumentError, "grid cell_padding must be non-negative" if cell_padding.negative?
      raise ArgumentError, "grid gutter must be non-negative" if gutter.negative?

      usable_width = width - (gutter * (cols - 1))
      usable_height = height - (gutter * (rows - 1))
      raise ArgumentError, "grid cells must have positive width" unless usable_width.positive?
      raise ArgumentError, "grid cells must have positive height" unless usable_height.positive?

      column_widths = resolve_grid_track_sizes(options["column_sizes"], cols, usable_width, "column_sizes")
      row_heights = resolve_grid_track_sizes(resolve_row_track_definition(options), rows, usable_height, "rows")

      border = options["border"]
      annotations = resolve_grid_annotations(options)
      {
        rows:,
        cols:,
        x:,
        y:,
        width:,
        height:,
        gutter:,
        cell_padding:,
        cell_width: column_widths.first,
        cell_height: row_heights.first,
        column_widths:,
        row_heights:,
        border: border ? stringify_keys(border) : nil,
        annotations:
      }
    end

    # Parses a grid definition into rows, cols, and options.
    #
    # @return [Array(Integer, Integer, Hash)]
    def parse_grid_definition(value)
      case value
      when String
        match = value.strip.match(/\A(\d+)x(\d+)\z/i)
        raise ArgumentError, "grid must look like 2x2" unless match

        rows = match[1].to_i
        cols = match[2].to_i
        [rows, cols, {}]
      when Hash
        grid = stringify_keys(value)
        if grid.key?("size")
          rows, cols, = parse_grid_definition(grid["size"])
        else
          rows = fetch_number(grid, "rows").to_i
          cols = fetch_number(grid, "cols").to_i
        end
        raise ArgumentError, "grid rows must be positive" unless rows.positive?
        raise ArgumentError, "grid cols must be positive" unless cols.positive?

        [rows, cols, grid]
      else
        raise ArgumentError, "grid must be a string like 2x2 or a hash"
      end
    end

    # Returns the row track definition when present.
    #
    # @return [Object, nil]
    def resolve_row_track_definition(options)
      return nil unless options.key?("size")

      options["row_sizes"]
    end

    # Resolves row or column percentages into absolute sizes.
    #
    # @return [Array<Float>]
    def resolve_grid_track_sizes(value, count, total_size, label)
      return Array.new(count, total_size / count.to_f) if value.nil?

      entries =
        case value
        when Array
          value
        when String
          value.strip.split(/\s+/)
        else
          raise ArgumentError, "grid #{label} must be an array or a space-separated string"
        end

      raise ArgumentError, "grid #{label} must have #{count} entries" unless entries.length == count

      weights = entries.map do |entry|
        text = entry.to_s.strip.delete_suffix("%")
        Float(text)
      rescue ArgumentError, TypeError
        raise ArgumentError, "grid #{label} entries must be numeric percentages"
      end
      raise ArgumentError, "grid #{label} entries must be positive" unless weights.all?(&:positive?)

      total_weight = weights.sum
      weights.map { |weight| total_size * (weight / total_weight.to_f) }
    end

    # Resolves optional grid annotation settings.
    #
    # @return [Hash, nil]
    def resolve_grid_annotations(options)
      value = options["annotations"]
      return nil if value.nil? || value == false

      annotation_options =
        case value
        when true
          {}
        when Hash
          stringify_keys(value)
        else
          raise ArgumentError, "grid annotations must be true or a hash"
        end

      border = stringify_keys(annotation_options.fetch("border", {}))
      text = stringify_keys(annotation_options.fetch("text", {}))

      {
        show: annotation_options.fetch("show", true),
        border: {
          "stroke_width" => fetch_number(border, "stroke_width", DEFAULT_ANNOTATION_BORDER_STROKE_WIDTH),
          "color" => border.fetch("color", DEFAULT_ANNOTATION_BORDER_COLOR),
          "brush" => border["brush"]
        },
        text: {
          "size" => fetch_number(text, "size", DEFAULT_ANNOTATION_TEXT_SIZE),
          "stroke_width" => fetch_number(text, "stroke_width", DEFAULT_ANNOTATION_TEXT_STROKE_WIDTH),
          "color" => text.fetch("color", DEFAULT_ANNOTATION_TEXT_COLOR),
          "brush" => text["brush"],
          "padding" => fetch_number(text, "padding", DEFAULT_ANNOTATION_TEXT_PADDING)
        }
      }
    end

    # Resolves an object's local bounding box into page coordinates.
    #
    # @return [Hash]
    def resolve_box(layout, object)
      geometry_keys = %w[x y width height]
      present = geometry_keys.select { |key| object.key?(key) }

      if present.empty?
        x = layout[:content_x] || layout[:x]
        y = layout[:content_y] || layout[:y]
        width = layout[:content_width] || layout[:width]
        height = layout[:content_height] || layout[:height]
      else
        missing = geometry_keys - present
        unless missing.empty?
          raise ArgumentError,
                "objects with partial box geometry must provide x, y, width, and height; missing: #{missing.join(', ')}"
        end

        x = map_x(layout, fetch_number(object, "x"))
        y = map_y(layout, fetch_number(object, "y"))
        width = scale_length(layout, fetch_number(object, "width"))
        height = scale_length(layout, fetch_number(object, "height"))
      end

      raise ArgumentError, "object width must be positive" unless width.positive?
      raise ArgumentError, "object height must be positive" unless height.positive?

      {
        x:,
        y:,
        width:,
        height:,
        center_x: x + (width / 2.0),
        center_y: y + (height / 2.0)
      }
    end

    # Draws one generic object from the YAML config.
    #
    # @return [void]
    def render_object(page, object, layout, base_dir:, used_cells:)
      type = object.fetch("type") { raise ArgumentError, "object type is required" }.to_s
      object = apply_cell_layout(object, layout, type, used_cells)
      style = style_options_for(object)
      brush = object.key?("brush") ? brush_for(object["brush"]) : default_brush_for_type(type)

      case type
      when "line"
        draw_line_object(page, object, layout, style:, brush:)
      when "semicircle_fill"
        draw_semicircle_fill_object(page, object, layout, style:, brush:)
      when "circle_fill"
        draw_circle_fill_object(page, object, layout, style:, brush:)
      when "circle_png_fill"
        draw_circle_png_fill_object(page, object, layout, style:, brush:)
      when "circle_outline"
        draw_circle_outline_object(page, object, layout, style:, brush:)
      when "circle_outline_fill"
        draw_circle_outline_fill_object(page, object, layout, brush:)
      when "circle_png_outline_fill"
        draw_circle_png_outline_fill_object(page, object, layout, brush:)
      when "isosceles_triangle_fill"
        draw_isosceles_triangle_fill_object(page, object, layout, style:, brush:)
      when "isosceles_triangle_outline"
        draw_isosceles_triangle_outline_object(page, object, layout, style:, brush:)
      when "isosceles_triangle_outline_fill"
        draw_isosceles_triangle_outline_fill_object(page, object, layout, brush:)
      when "right_triangle_fill"
        draw_right_triangle_fill_object(page, object, layout, style:, brush:)
      when "right_triangle_outline"
        draw_right_triangle_outline_object(page, object, layout, style:, brush:)
      when "right_triangle_outline_fill"
        draw_right_triangle_outline_fill_object(page, object, layout, brush:)
      when "rectangle_fill"
        draw_rectangle_fill_object(page, object, layout, style:, brush:)
      when "rectangle_png_fill"
        draw_rectangle_png_fill_object(page, object, layout, style:, brush:)
      when "rectangle_outline"
        draw_rectangle_outline_object(page, object, layout, style:, brush:)
      when "rectangle_outline_fill"
        draw_rectangle_outline_fill_object(page, object, layout, brush:)
      when "rectangle_png_outline_fill"
        draw_rectangle_png_outline_fill_object(page, object, layout, brush:)
      when "star"
        draw_star_object(page, object, layout, style:, brush:)
      when "polygon_outline"
        draw_polygon_outline_object(page, object, layout, style:, brush:)
      when "regular_polygon_outline"
        draw_regular_polygon_outline_object(page, object, layout, style:, brush:)
      when "regular_polygon_fill"
        draw_regular_polygon_fill_object(page, object, layout, style:, brush:)
      when "regular_polygon_outline_fill"
        draw_regular_polygon_outline_fill_object(page, object, layout, brush:)
      when "parallelogram"
        draw_parallelogram_object(page, object, layout, style:, brush:)
      when "text"
        draw_text_object(page, object, layout, style:, brush:)
      when "shadow_text"
        draw_shadow_text_object(page, object, layout, style:, brush:)
      when "image"
        draw_image_object(page, object, layout, base_dir:, brush:)
      when "yaml"
        draw_yaml_object(page, object, layout, base_dir:)
      else
        raise ArgumentError, "unsupported object type: #{type}"
      end
    end

    # Returns the default brush for one object type.
    #
    # @return [Integer]
    def default_brush_for_type(type)
      %w[image circle_png_fill circle_png_outline_fill rectangle_png_fill rectangle_png_outline_fill].include?(type) ? DEFAULT_IMAGE_BRUSH : Shapes::DEFAULT_BRUSH
    end

    # Converts nested hash keys to strings.
    #
    # @return [Object]
    def stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, inner), result|
          result[key.to_s] = stringify_keys(inner)
        end
      when Array
        value.map { |item| stringify_keys(item) }
      else
        value
      end
    end

    # Resolves a cell-based object into explicit box geometry.
    #
    # @return [Hash]
    def apply_cell_layout(object, layout, type, used_cells)
      return object unless object.key?("cell")

      raise ArgumentError, "cell placement requires a canvas grid" unless layout[:grid]
      ensure_no_explicit_geometry_with_cell!(object)

      cell_index = parse_cell_identifier(object["cell"], layout[:grid])
      outer_box = grid_cell_outer_box(layout[:grid], cell_index)
      inner_box = inset_box(outer_box, layout[:grid][:cell_padding])
      placement = (object["placement"] || "center").to_s
      scale = resolve_cell_scale(object)

      updated = object.dup
      updated["wrap"] = true if %w[text shadow_text].include?(type) && !updated.key?("wrap")

      box =
        if square_fit_type?(type)
          side = [inner_box[:width], inner_box[:height]].min * scale
          place_box_in_box(inner_box, side, side, placement)
        elsif full_cell_type?(type)
          place_box_in_box(inner_box, inner_box[:width] * scale, inner_box[:height] * scale, placement)
        else
          raise ArgumentError, "object type #{type} does not support cell placement without explicit geometry"
        end

      updated["x"] = box[:x]
      updated["y"] = box[:y]
      updated["width"] = box[:width]
      updated["height"] = box[:height]
      updated
    end

    # Resolves an optional per-object cell scale.
    #
    # @return [Float]
    def resolve_cell_scale(object)
      return 1.0 unless object.key?("scale")

      scale = fetch_number(object, "scale")
      raise ArgumentError, "cell scale must be greater than 0 and less than 100" unless scale.positive? && scale < 100

      scale > 1.0 ? scale / 100.0 : scale
    end

    # Returns whether the object type should fit a square inside a cell.
    #
    # @return [Boolean]
    def square_fit_type?(type)
      %w[
        semicircle_fill
        circle_fill
        circle_png_fill
        circle_outline
        circle_outline_fill
        circle_png_outline_fill
        star
        regular_polygon_outline
        regular_polygon_fill
        regular_polygon_outline_fill
      ].include?(type)
    end

    # Returns whether the object type should fill the cell box directly.
    #
    # @return [Boolean]
    def full_cell_type?(type)
      %w[
        rectangle_fill
        rectangle_png_fill
        rectangle_outline
        rectangle_outline_fill
        rectangle_png_outline_fill
        isosceles_triangle_fill
        isosceles_triangle_outline
        isosceles_triangle_outline_fill
        right_triangle_fill
        right_triangle_outline
        right_triangle_outline_fill
        text
        shadow_text
        image
        yaml
      ].include?(type)
    end

    # Raises when an object combines cell placement with explicit geometry.
    #
    # @return [void]
    def ensure_no_explicit_geometry_with_cell!(object)
      geometry_keys = %w[
        x y width height
        center_x center_y radius
        x1 y1 x2 y2 x3 y3
        triangle_width
        points
      ]
      used = geometry_keys.select { |key| object.key?(key) }
      return if used.empty?

      raise ArgumentError, "cell placement cannot be combined with explicit geometry keys: #{used.join(', ')}"
    end

    # Parses one cell identifier.
    #
    # @return [Integer]
    def parse_cell_identifier(value, grid)
      text = value.to_s.strip
      if text.match?(/\A\d+\z/)
        index = text.to_i
      elsif (match = text.match(/\Acell(\d+)\z/i))
        index = match[1].to_i
      elsif (match = text.match(/\Ar(\d+)c(\d+)\z/i))
        row = match[1].to_i
        col = match[2].to_i
        raise ArgumentError, "grid row out of range in cell #{value}" unless row.between?(1, grid[:rows])
        raise ArgumentError, "grid col out of range in cell #{value}" unless col.between?(1, grid[:cols])

        index = ((row - 1) * grid[:cols]) + col
      else
        raise ArgumentError, "unsupported cell identifier: #{value}"
      end

      max = grid[:rows] * grid[:cols]
      raise ArgumentError, "cell index out of range: #{value}" unless index.between?(1, max)

      index
    end

    # Returns the outer box of one grid cell.
    #
    # @return [Hash]
    def grid_cell_outer_box(grid, cell_index)
      zero = cell_index - 1
      row = zero / grid[:cols]
      col = zero % grid[:cols]
      width = grid[:column_widths][col]
      height = grid[:row_heights][row]
      x = grid[:x] + grid[:column_widths].take(col).sum + (col * grid[:gutter])
      y = grid[:y] + grid[:row_heights].take(row).sum + (row * grid[:gutter])
      {
        x:,
        y:,
        width:,
        height:,
        center_x: x + (width / 2.0),
        center_y: y + (height / 2.0)
      }
    end

    # Insets a box by a uniform amount.
    #
    # @return [Hash]
    def inset_box(box, inset)
      width = box[:width] - (inset * 2.0)
      height = box[:height] - (inset * 2.0)
      raise ArgumentError, "grid cell padding leaves no usable width" unless width.positive?
      raise ArgumentError, "grid cell padding leaves no usable height" unless height.positive?

      {
        x: box[:x] + inset,
        y: box[:y] + inset,
        width:,
        height:,
        center_x: box[:x] + inset + (width / 2.0),
        center_y: box[:y] + inset + (height / 2.0)
      }
    end

    # Places a child box inside a parent box using named placement.
    #
    # @return [Hash]
    def place_box_in_box(parent_box, width, height, placement)
      x = parent_box[:x] + placement_x(placement, width, parent_box[:width])
      y = parent_box[:y] + placement_y(placement, height, parent_box[:height])
      {
        x:,
        y:,
        width:,
        height:,
        center_x: x + (width / 2.0),
        center_y: y + (height / 2.0)
      }
    end

    # Resolves a square fitted into a box using the object's placement.
    #
    # @return [Hash]
    def resolve_square_fit_box(layout, object)
      box = resolve_box(layout, object)
      placement = (object["placement"] || "center").to_s
      side = [box[:width], box[:height]].min
      place_box_in_box(box, side, side, placement)
    end

    # Draws optional grid cell borders.
    #
    # @return [void]
    def draw_grid_borders(page, layout)
      grid = layout[:grid]
      return unless grid && grid[:border]

      border = grid[:border]
      stroke_width = fetch_number(border, "stroke_width", DEFAULT_STROKE_WIDTH)
      style = style_options_for(border)
      brush = brush_for(border["brush"])

      (1..(grid[:rows] * grid[:cols])).each do |cell_index|
        box = grid_cell_outer_box(grid, cell_index)
        Shapes.draw_box(
          page,
          box[:x],
          box[:y],
          box[:x] + box[:width],
          box[:y] + box[:height],
          stroke_width,
          brush:,
          **style
        )
      end
    end

    # Draws annotation borders and text for a grid, when enabled.
    #
    # @return [void]
    def draw_grid_annotations(page, layout)
      grid = layout[:grid]
      return unless grid && grid[:annotations] && grid[:annotations][:show]

      draw_annotation_borders(page, grid)
      draw_annotation_text(page, grid)
    end

    # Draws the annotation border set.
    #
    # @return [void]
    def draw_annotation_borders(page, grid)
      border = grid[:annotations][:border]
      stroke_width = fetch_number(border, "stroke_width", DEFAULT_ANNOTATION_BORDER_STROKE_WIDTH)
      style = style_options_for(border)
      brush = border["brush"] ? brush_for(border["brush"]) : Shapes::DEFAULT_BRUSH

      (1..(grid[:rows] * grid[:cols])).each do |cell_index|
        box = grid_cell_outer_box(grid, cell_index)
        Shapes.draw_box(
          page,
          box[:x],
          box[:y],
          box[:x] + box[:width],
          box[:y] + box[:height],
          stroke_width,
          brush:,
          **style
        )
      end
    end

    # Draws the annotation text for every grid cell.
    #
    # @return [void]
    def draw_annotation_text(page, grid)
      text = grid[:annotations][:text]
      size = fetch_number(text, "size", DEFAULT_ANNOTATION_TEXT_SIZE)
      stroke_width = fetch_number(text, "stroke_width", DEFAULT_ANNOTATION_TEXT_STROKE_WIDTH)
      padding = fetch_number(text, "padding", DEFAULT_ANNOTATION_TEXT_PADDING)
      style = style_options_for(text)
      brush = text["brush"] ? brush_for(text["brush"]) : Shapes::DEFAULT_BRUSH
      line_height = size * 1.2

      (1..(grid[:rows] * grid[:cols])).each do |cell_index|
        box = grid_cell_outer_box(grid, cell_index)
        baseline = (box[:y] + padding) - LineFont.baseline_to_top(size)
        annotation_lines_for_cell(box).each_with_index do |line, index|
          Shapes.text(
            page,
            line,
            box[:x] + padding,
            baseline + (index * line_height),
            size:,
            stroke_width:,
            brush:,
            **style
          )
        end
      end
    end

    # Returns the annotation text lines for one grid cell.
    #
    # @return [Array<String>]
    def annotation_lines_for_cell(box)
      [
        "x=#{format_annotation_number(box[:x])} y=#{format_annotation_number(box[:y])}",
        "w=#{format_annotation_number(box[:width])} h=#{format_annotation_number(box[:height])}"
      ]
    end

    # Formats one annotation number compactly.
    #
    # @return [String]
    def format_annotation_number(value)
      format("%.2f", value).sub(/\.?0+\z/, "")
    end

    # Returns the horizontal offset for a named placement.
    #
    # @return [Float]
    def placement_x(placement, width, available_width)
      case placement
      when "top", "bottom", "center"
        (available_width - width) / 2.0
      when "left", "top-left", "bottom-left"
        0.0
      when "right", "top-right", "bottom-right"
        available_width - width
      else
        raise ArgumentError, "unsupported placement: #{placement}"
      end
    end

    # Returns the vertical offset for a named placement.
    #
    # @return [Float]
    def placement_y(placement, height, available_height)
      case placement
      when "left", "right", "center"
        (available_height - height) / 2.0
      when "top", "top-left", "top-right"
        0.0
      when "bottom", "bottom-left", "bottom-right"
        available_height - height
      else
        raise ArgumentError, "unsupported placement: #{placement}"
      end
    end

    # Builds normalized drawing style options from an object config.
    #
    # @return [Hash]
    def style_options_for(object, prefix = nil)
      color_key = prefixed_key(prefix, "color")
      rgba_key = prefixed_key(prefix, "rgba")
      style_value =
        if object.key?(rgba_key)
          parse_rgba(object[rgba_key])
        elsif object.key?(color_key)
          parse_color(object[color_key])
        else
          Shapes::DEFAULT_RGBA
        end

      Shapes.style_options(style_value)
    end

    # Returns shadow text style options using the shadow-specific keyword names.
    #
    # @return [Hash]
    def shadow_style_options_for(object)
      style = style_options_for(object, "shadow")
      {
        shadow_rgba: style.fetch(:rgba),
        shadow_color: style.fetch(:color)
      }
    end

    # Parses a color value into either a tablet color constant or RGBA integer.
    #
    # @return [Integer]
    def parse_color(value)
      return parse_rgba(value) if value.is_a?(Integer)

      text = value.to_s.strip
      return parse_rgba(text) if text.start_with?("0x", "0X") || text.match?(/\A[0-9A-Fa-f]{8}\z/)

      key = text.upcase.gsub(/[^A-Z0-9]+/, "_")
      if RmPage::Colour.const_defined?(key, false)
        RmPage::Colour.const_get(key, false)
      else
        parse_rgba(text)
      end
    end

    # Parses a hex RGBA string or integer into an ARGB integer.
    #
    # @return [Integer]
    def parse_rgba(value)
      return value if value.is_a?(Integer)

      text = value.to_s.strip
      text = text[2..] if text.start_with?("0x", "0X")
      raise ArgumentError, "rgba must be 8 hex digits" unless text.match?(/\A[0-9A-Fa-f]{8}\z/)

      text.to_i(16)
    end

    # Parses a list of colors into tablet colors or RGBA integers.
    #
    # @return [Array<Integer>]
    def parse_color_list(values)
      raise ArgumentError, "colors must be an array" unless values.is_a?(Array)

      values.map { |value| parse_color(value) }
    end

    # Parses an optional brush name.
    #
    # @return [Integer]
    def brush_for(value)
      return Shapes::DEFAULT_BRUSH if value.nil?
      return value if value.is_a?(Integer)

      key = value.to_s.strip.upcase.gsub(/[^A-Z0-9]+/, "_")
      raise ArgumentError, "unsupported brush: #{value}" unless RmPage::Pen.const_defined?(key, false)

      RmPage::Pen.const_get(key, false)
    end

    # Fetches a numeric field from an object hash.
    #
    # @return [Float]
    def fetch_number(object, key, default = nil)
      value = object.fetch(key, default)
      raise ArgumentError, "#{key} is required" if value.nil?

      Float(value)
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{key} must be numeric"
    end

    # Returns a key with an optional prefix.
    #
    # @return [String]
    def prefixed_key(prefix, suffix)
      prefix ? "#{prefix}_#{suffix}" : suffix
    end

    # Returns wrapped text lines for the given width.
    #
    # @return [Array<String>]
    def wrap_text_lines(text, max_width, size:, style:, font:, mono:)
      return text.to_s.split("\n") if max_width.nil? || max_width <= 0

      wrapped = []
      text.to_s.split("\n", -1).each do |paragraph|
        if paragraph.empty?
          wrapped << ""
          next
        end

        current = +""
        paragraph.split(/\s+/).each do |word|
          candidate = current.empty? ? word : "#{current} #{word}"
          if LineFont.text_width(candidate, size:, style:, font:, mono:) <= max_width || current.empty?
            current = candidate
          else
            wrapped << current
            current = word
          end
        end
        wrapped << current unless current.empty?
      end
      wrapped
    end

    # Resolves a list of local points into page coordinates.
    #
    # @return [Array<Array<Float>>]
    def resolve_points(layout, values)
      raise ArgumentError, "points must be an array" unless values.is_a?(Array)

      values.map do |value|
        raise ArgumentError, "each point must have two values" unless value.is_a?(Array) && value.length == 2

        [map_x(layout, Float(value[0])), map_y(layout, Float(value[1]))]
      end
    rescue ArgumentError, TypeError
      raise ArgumentError, "points must be numeric coordinate pairs"
    end

    # Maps a local x coordinate into page coordinates.
    #
    # @return [Float]
    def map_x(layout, value)
      layout[:x] + (value.to_f * layout.fetch(:scale, 1.0))
    end

    # Maps a local y coordinate into page coordinates.
    #
    # @return [Float]
    def map_y(layout, value)
      layout[:y] + (value.to_f * layout.fetch(:scale, 1.0))
    end

    # Scales a local length into page units.
    #
    # @return [Float]
    def scale_length(layout, value)
      value.to_f * layout.fetch(:scale, 1.0)
    end

    # Builds a nested layout by fitting a child canvas into a parent box.
    #
    # @return [Hash]
    def nested_layout_for(parent_layout, object, child_config)
      box = resolve_box(parent_layout, object)
      child_canvas = resolve_canvas_layout(stringify_keys(child_config.fetch("canvas", {})))
      scale = [box[:width] / child_canvas[:width], box[:height] / child_canvas[:height]].min
      raise ArgumentError, "nested yaml object box is too small" unless scale.positive?

      target_width = child_canvas[:width] * scale
      target_height = child_canvas[:height] * scale
      placement = (object["placement"] || "center").to_s
      fitted_box = place_box_in_box(box, target_width, target_height, placement)

      {
        x: fitted_box[:x],
        y: fitted_box[:y],
        width: child_canvas[:width],
        height: child_canvas[:height],
        placement: "nested",
        tablet: child_canvas[:tablet],
        physical_width: parent_layout[:physical_width],
        physical_height: parent_layout[:physical_height],
        scale:
      }
    end

    # Resolves a box or a center/radius triple into circle geometry.
    #
    # @return [Hash]
    def resolve_circle_geometry(layout, object)
      if object.key?("center_x") || object.key?("center_y") || object.key?("radius")
        center_x = map_x(layout, fetch_number(object, "center_x"))
        center_y = map_y(layout, fetch_number(object, "center_y"))
        radius = scale_length(layout, fetch_number(object, "radius"))
        raise ArgumentError, "radius must be positive" unless radius.positive?

        { center_x:, center_y:, radius: }
      else
        box = resolve_square_fit_box(layout, object)
        {
          center_x: box[:center_x],
          center_y: box[:center_y],
          radius: [box[:width], box[:height]].min / 2.0
        }
      end
    end

    # Resolves a rotation value, optionally using a named direction fallback.
    #
    # @return [Float]
    def resolve_rotation(object, direction_map = nil, default = 0.0)
      return fetch_number(object, "rotation") if object.key?("rotation")

      direction = object["direction"]
      return default if direction.nil?
      raise ArgumentError, "direction is not supported for this object" unless direction_map

      mapped = direction_map[direction.to_s]
      raise ArgumentError, "unsupported direction: #{direction}" if mapped.nil?

      mapped
    end

    # Returns the points of a rotated rectangle fitted into a box.
    #
    # @return [Array<Array<Float>>]
    def box_polygon_points(box, rotation = 0.0)
      angle = rotation.to_f * Math::PI / 180.0
      cos = Math.cos(angle)
      sin = Math.sin(angle)
      half_width = box[:width] / 2.0
      half_height = box[:height] / 2.0

      offsets = [
        [-half_width, -half_height],
        [half_width, -half_height],
        [half_width, half_height],
        [-half_width, half_height]
      ]

      offsets.map do |dx, dy|
        [
          box[:center_x] + (dx * cos) - (dy * sin),
          box[:center_y] + (dx * sin) + (dy * cos)
        ]
      end
    end

    # Returns triangle points from a box and orientation.
    #
    # @return [Array<Array<Float>>]
    def box_triangle_points(box, mode:, rotation: 0.0)
      angle = rotation.to_f * Math::PI / 180.0
      cos = Math.cos(angle)
      sin = Math.sin(angle)
      base_points = case mode
                    when :isosceles
                      [
                        [0.0, -0.5],
                        [0.5, 0.5],
                        [-0.5, 0.5]
                      ]
                    when :right
                      [
                        [-0.5, -0.5],
                        [-0.5, 0.5],
                        [0.5, 0.5]
                      ]
                    else
                      raise ArgumentError, "unsupported triangle mode: #{mode}"
                    end

      rotated = base_points.map do |x, y|
        [
          (x * cos) - (y * sin),
          (x * sin) + (y * cos)
        ]
      end

      min_x = rotated.min_by { |x, _y| x }.first
      max_x = rotated.max_by { |x, _y| x }.first
      min_y = rotated.min_by { |_x, y| y }.last
      max_y = rotated.max_by { |_x, y| y }.last
      rotated_width = max_x - min_x
      rotated_height = max_y - min_y

      rotated.map do |x, y|
        [
          box[:x] + ((x - min_x) / rotated_width) * box[:width],
          box[:y] + ((y - min_y) / rotated_height) * box[:height]
        ]
      end
    end

    # Draws an isosceles triangle fill from resolved vertex points.
    #
    # @return [void]
    def draw_isosceles_triangle_fill_from_points(page, points, style:, brush:)
      apex = points[0]
      base_start = points[1]
      base_end = points[2]
      mid_x = (base_start[0] + base_end[0]) / 2.0
      mid_y = (base_start[1] + base_end[1]) / 2.0
      width = Math.hypot(base_end[0] - base_start[0], base_end[1] - base_start[1])

      Shapes.triangle(page, apex[0], apex[1], mid_x, mid_y, width, brush:, **style)
    end

    # Draws a right triangle fill from resolved vertex points.
    #
    # @return [void]
    def draw_right_triangle_fill_from_points(page, points, style:, brush:)
      edges = [
        [points[0], points[1]],
        [points[1], points[2]],
        [points[2], points[0]]
      ]
      hypotenuse = edges.max_by do |(a, b)|
        Math.hypot(b[0] - a[0], b[1] - a[1])
      end

      a, c = hypotenuse
      b = points.find { |point| point != a && point != c }
      Shapes.right_triangle(page, a[0], a[1], b[0], b[1], c[0], c[1], brush:, **style)
    end

    # Returns the vertices for an isosceles triangle from explicit point geometry.
    #
    # @return [Array<Array<Float>>]
    def isosceles_triangle_points_from_segment(layout, object)
      ax = map_x(layout, fetch_number(object, "x1"))
      ay = map_y(layout, fetch_number(object, "y1"))
      bx = map_x(layout, fetch_number(object, "x2"))
      by = map_y(layout, fetch_number(object, "y2"))
      width = scale_length(layout, fetch_number(object, "triangle_width"))

      dx = bx - ax
      dy = by - ay
      len = Math.hypot(dx, dy)
      raise ArgumentError, "triangle segment must not be zero length" if len.zero?

      ux = dx / len
      uy = dy / len
      px = -uy * (width / 2.0)
      py = ux * (width / 2.0)

      [
        [ax, ay],
        [bx + px, by + py],
        [bx - px, by - py]
      ]
    end

    # Resolves isosceles triangle points from either point-based or box-based geometry.
    #
    # @return [Array<Array<Float>>]
    def resolve_isosceles_triangle_points(layout, object)
      if object.key?("x1")
        isosceles_triangle_points_from_segment(layout, object)
      else
        box = resolve_box(layout, object)
        rotation = resolve_rotation(
          object,
          { "up" => 0.0, "right" => 90.0, "down" => 180.0, "left" => 270.0 }
        )
        box_triangle_points(box, mode: :isosceles, rotation:)
      end
    end

    # Resolves right triangle points from either point-based or box-based geometry.
    #
    # @return [Array<Array<Float>>]
    def resolve_right_triangle_points(layout, object)
      if object.key?("x1")
        [
          [map_x(layout, fetch_number(object, "x1")), map_y(layout, fetch_number(object, "y1"))],
          [map_x(layout, fetch_number(object, "x2")), map_y(layout, fetch_number(object, "y2"))],
          [map_x(layout, fetch_number(object, "x3")), map_y(layout, fetch_number(object, "y3"))]
        ]
      else
        box = resolve_box(layout, object)
        rotation = resolve_rotation(
          object,
          {
            "lower-left" => 0.0,
            "upper-left" => 90.0,
            "upper-right" => 180.0,
            "lower-right" => 270.0
          }
        )
        box_triangle_points(box, mode: :right, rotation:)
      end
    end

    # Returns a rotation for regular polygons from explicit rotation or named direction.
    #
    # @return [Float]
    def resolve_regular_polygon_rotation(object, sides)
      return fetch_number(object, "rotation") if object.key?("rotation")

      direction = object["direction"]
      return 0.0 if direction.nil?

      direction = direction.to_s
      if sides.even?
        case direction
        when "vertical"
          0.0
        when "horizontal"
          180.0 / sides.to_f
        else
          raise ArgumentError, "even-sided regular polygons support direction horizontal or vertical"
        end
      else
        case direction
        when "up"
          0.0
        when "down"
          180.0
        else
          raise ArgumentError, "odd-sided regular polygons support direction up or down"
        end
      end
    end

    # Draws a line object.
    #
    # @example YAML object
    #   - type: line
    #     x1: 40
    #     y1: 270
    #     x2: 860
    #     y2: 270
    #     stroke_width: 10
    #     rgba: "0xFF444444"
    # @return [void]
    def draw_line_object(page, object, layout, style:, brush:)
      x1 = map_x(layout, fetch_number(object, "x1"))
      y1 = map_y(layout, fetch_number(object, "y1"))
      x2 = map_x(layout, fetch_number(object, "x2"))
      y2 = map_y(layout, fetch_number(object, "y2"))
      width = scale_length(layout, fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH))
      Shapes.draw_line(page, x1, y1, x2, y2, width, brush:, **style)
    end

    # Draws a filled semicircle object.
    #
    # @example YAML object
    #   - type: semicircle_fill
    #     x: 650
    #     y: 210
    #     width: 140
    #     height: 140
    #     direction: right
    #     color: blue
    # @return [void]
    def draw_semicircle_fill_object(page, object, layout, style:, brush:)
      circle = resolve_circle_geometry(layout, object)
      rotation = resolve_rotation(
        object,
        { "right" => 0.0, "down" => 90.0, "left" => 180.0, "up" => 270.0 }
      )
      angle = rotation * Math::PI / 180.0
      Shapes.semicircle(page, circle[:center_x], circle[:center_y], circle[:radius], angle, brush:, **style)
    end

    # Draws a filled circle object.
    #
    # @example YAML object
    #   - type: circle_fill
    #     x: 40
    #     y: 40
    #     width: 160
    #     height: 160
    #     color: red
    # @return [void]
    def draw_circle_fill_object(page, object, layout, style:, brush:)
      circle = resolve_circle_geometry(layout, object)
      Shapes.circle(page, circle[:center_x], circle[:center_y], circle[:radius], brush:, **style)
    end

    # Draws a PNG-backed filled circle object.
    #
    # @return [void]
    def draw_circle_png_fill_object(page, object, layout, style:, brush:)
      draw_circle_png_object(page, object, layout, brush:, fill_style: style)
    end

    # Draws a circle outline object.
    #
    # @return [void]
    def draw_circle_outline_object(page, object, layout, style:, brush:)
      circle = resolve_circle_geometry(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      radius = circle[:radius] - (stroke_width / 2.0)
      raise ArgumentError, "circle outline is too small for its stroke width" unless radius.positive?

      steps = 40
      points = Array.new(steps + 1) do |index|
        angle = (2.0 * Math::PI * index) / steps
        [
          circle[:center_x] + (radius * Math.cos(angle)),
          circle[:center_y] + (radius * Math.sin(angle))
        ]
      end
      Shapes.draw_polyline(page, points, stroke_width, brush:, **style)
    end

    # Draws a circle with separate fill and outline styles.
    #
    # @example YAML object
    #   - type: circle_outline_fill
    #     x: 250
    #     y: 40
    #     width: 160
    #     height: 160
    #     fill_rgba: "0xFFBFE3FF"
    #     outline_color: blue
    #     stroke_width: 6
    # @return [void]
    def draw_circle_outline_fill_object(page, object, layout, brush:)
      draw_circle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_circle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a PNG-backed circle with separate fill and outline styles.
    #
    # @return [void]
    def draw_circle_png_outline_fill_object(page, object, layout, brush:)
      draw_circle_png_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_circle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a filled isosceles triangle object.
    #
    # @example YAML object
    #   - type: isosceles_triangle_fill
    #     x1: 180
    #     y1: 560
    #     x2: 360
    #     y2: 650
    #     triangle_width: 120
    #     color: green
    # @return [void]
    def draw_isosceles_triangle_fill_object(page, object, layout, style:, brush:)
      if object.key?("x1")
        ax = map_x(layout, fetch_number(object, "x1"))
        ay = map_y(layout, fetch_number(object, "y1"))
        bx = map_x(layout, fetch_number(object, "x2"))
        by = map_y(layout, fetch_number(object, "y2"))
        width = scale_length(layout, fetch_number(object, "triangle_width"))
        Shapes.triangle(page, ax, ay, bx, by, width, brush:, **style)
      else
        draw_isosceles_triangle_fill_from_points(page, resolve_isosceles_triangle_points(layout, object), style:, brush:)
      end
    end

    # Draws an isosceles triangle outline object.
    #
    # @return [void]
    def draw_isosceles_triangle_outline_object(page, object, layout, style:, brush:)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      Shapes.polygon_outline(page, resolve_isosceles_triangle_points(layout, object), stroke_width, brush:, **style)
    end

    # Draws an isosceles triangle with separate fill and outline styles.
    #
    # @return [void]
    def draw_isosceles_triangle_outline_fill_object(page, object, layout, brush:)
      draw_isosceles_triangle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_isosceles_triangle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a filled right triangle object.
    #
    # @example YAML object
    #   - type: right_triangle_fill
    #     x1: 520
    #     y1: 500
    #     x2: 520
    #     y2: 700
    #     x3: 760
    #     y3: 700
    #     color: magenta
    # @return [void]
    def draw_right_triangle_fill_object(page, object, layout, style:, brush:)
      if object.key?("x1")
        ax = map_x(layout, fetch_number(object, "x1"))
        ay = map_y(layout, fetch_number(object, "y1"))
        bx = map_x(layout, fetch_number(object, "x2"))
        by = map_y(layout, fetch_number(object, "y2"))
        cx = map_x(layout, fetch_number(object, "x3"))
        cy = map_y(layout, fetch_number(object, "y3"))
        Shapes.right_triangle(page, ax, ay, bx, by, cx, cy, brush:, **style)
      else
        draw_right_triangle_fill_from_points(page, resolve_right_triangle_points(layout, object), style:, brush:)
      end
    end

    # Draws a right triangle outline object.
    #
    # @return [void]
    def draw_right_triangle_outline_object(page, object, layout, style:, brush:)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      Shapes.polygon_outline(page, resolve_right_triangle_points(layout, object), stroke_width, brush:, **style)
    end

    # Draws a right triangle with separate fill and outline styles.
    #
    # @return [void]
    def draw_right_triangle_outline_fill_object(page, object, layout, brush:)
      draw_right_triangle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_right_triangle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a filled rectangle object.
    #
    # @return [void]
    def draw_rectangle_fill_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      rotation = resolve_rotation(object)
      if rotation.zero?
        Shapes.rect(page, box[:x], box[:center_y], box[:x] + box[:width], box[:center_y], box[:height], brush:, **style)
      else
        Shapes.polygon_fill(page, box_polygon_points(box, rotation), colors: [style[:color] == RmPage::Colour::RGBA ? style[:rgba] : style[:color]], brush:)
      end
    end

    # Draws a PNG-backed filled rectangle object.
    #
    # @return [void]
    def draw_rectangle_png_fill_object(page, object, layout, style:, brush:)
      draw_rectangle_png_object(page, object, layout, brush:, fill_style: style)
    end

    # Draws a rectangle outline object.
    #
    # @example YAML object
    #   - type: rectangle_outline
    #     x: 720
    #     y: 50
    #     width: 140
    #     height: 110
    #     stroke_width: 5
    #     color: black
    # @return [void]
    def draw_rectangle_outline_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      rotation = resolve_rotation(object)
      if rotation.zero?
        Shapes.draw_box(page, box[:x], box[:y], box[:x] + box[:width], box[:y] + box[:height], stroke_width, brush:, **style)
      else
        Shapes.polygon_outline(page, box_polygon_points(box, rotation), stroke_width, brush:, **style)
      end
    end

    # Draws a rectangle with separate fill and outline styles.
    #
    # @return [void]
    def draw_rectangle_outline_fill_object(page, object, layout, brush:)
      draw_rectangle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_rectangle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a PNG-backed rectangle with separate fill and outline styles.
    #
    # @return [void]
    def draw_rectangle_png_outline_fill_object(page, object, layout, brush:)
      draw_rectangle_png_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_rectangle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a PNG-backed circle using the RGBA grid image path.
    #
    # @return [void]
    def draw_circle_png_object(page, object, layout, brush:, fill_style:)
      box = resolve_square_fit_box(layout, object)
      pixel_size = resolve_png_pixel_size(layout, object)
      diameter_pixels = [(box[:width] / pixel_size).round, 1].max
      antialias_samples = fetch_number(object, "antialias_samples", 4).to_i

      rgba_grid = Shapes.circle_rgba_grid(
        diameter_pixels,
        rgba: style_rgba(fill_style),
        antialias_samples:
      )

      draw_generated_rgba_grid(page, box, rgba_grid, pixel_size, brush:, object:)
    end

    # Draws a PNG-backed rectangle using the RGBA grid image path.
    #
    # @return [void]
    def draw_rectangle_png_object(page, object, layout, brush:, fill_style:)
      box = resolve_box(layout, object)
      pixel_size = resolve_png_pixel_size(layout, object)
      width_pixels = [(box[:width] / pixel_size).round, 1].max
      height_pixels = [(box[:height] / pixel_size).round, 1].max
      antialias_samples = fetch_number(object, "antialias_samples", 4).to_i

      rgba_grid = Shapes.rectangle_rgba_grid(
        width_pixels,
        height_pixels,
        rgba: style_rgba(fill_style),
        antialias_samples:
      )

      draw_generated_rgba_grid(page, box, rgba_grid, pixel_size, brush:, object:)
    end

    # Draws a generated RGBA grid centered within a target box.
    #
    # @return [void]
    def draw_generated_rgba_grid(page, box, rgba_grid, pixel_size, brush:, object:)
      grid_width = rgba_grid.first.length * pixel_size
      grid_height = rgba_grid.length * pixel_size
      placement = (object["placement"] || "center").to_s
      fitted_box = place_box_in_box(box, grid_width, grid_height, placement)
      pixel_gap = fetch_number(object, "pixel_gap", -3.0)

      Shapes.draw_rgba_grid(page, rgba_grid, fitted_box[:x], fitted_box[:y], pixel_size, gap: pixel_gap, brush:)
    end

    # Resolves the target rendered pixel size for PNG-backed generated shapes.
    #
    # @return [Float]
    def resolve_png_pixel_size(layout, object)
      pixel_size = scale_length(layout, fetch_number(object, "pixel_size", 6.0))
      raise ArgumentError, "pixel_size must be positive" unless pixel_size.positive?

      pixel_size
    end

    # Converts a normalized style hash into an RGBA integer.
    #
    # @return [Integer]
    def style_rgba(style)
      return style[:rgba] if style[:color] == RmPage::Colour::RGBA

      case style[:color]
      when RmPage::Colour::BLACK then 0xFF000000
      when RmPage::Colour::GREY then 0xFF808080
      when RmPage::Colour::WHITE then 0xFFFFFFFF
      when RmPage::Colour::BLUE then 0xFF0000FF
      when RmPage::Colour::RED then 0xFFFF0000
      when RmPage::Colour::GREEN then 0xFF00AA00
      when RmPage::Colour::CYAN then 0xFF00C8C8
      when RmPage::Colour::MAGENTA then 0xFFC800C8
      when RmPage::Colour::YELLOW then 0xFFFFD400
      when RmPage::Colour::HIGHLIGHTER_YELLOW then 0x66F0D54A
      when RmPage::Colour::HIGHLIGHTER_GREEN then 0x665CC45C
      when RmPage::Colour::HIGHLIGHTER_PINK then 0x66FF66B3
      when RmPage::Colour::HIGHLIGHTER_GREY then 0x66909090
      else
        Shapes::DEFAULT_RGBA
      end
    end

    # Draws a star object using one or more cycled colours.
    #
    # @example YAML object
    #   - type: star
    #     x: 1085
    #     y: 70
    #     width: 260
    #     height: 300
    #     points: 6
    #     colors:
    #       - yellow
    #       - magenta
    #       - cyan
    # @return [void]
    def draw_star_object(page, object, layout, style:, brush:)
      box = resolve_square_fit_box(layout, object)
      point_count = fetch_number(object, "point_count", object["points"]).to_i
      wide_point_percent = fetch_number(object, "wide_point_percent", 31.0)
      raw_star_width = fetch_number(object, "star_width", -1.0)
      star_width = raw_star_width.negative? ? raw_star_width : scale_length(layout, raw_star_width)
      rotation = fetch_number(object, "rotation", 0.0)
      radius = [box[:width], box[:height]].min / 2.0

      if object.key?("colors")
        Shapes.stars_colored(
          page,
          box[:center_x],
          box[:center_y],
          radius,
          point_count,
          wide_point_percent,
          star_width,
          colors: parse_color_list(object["colors"]),
          rotation:,
          brush:
        )
      else
        Shapes.stars(
          page,
          box[:center_x],
          box[:center_y],
          radius,
          point_count,
          wide_point_percent,
          star_width,
          rotation:,
          brush:,
          **style
        )
      end
    end

    # Draws a freeform polygon outline object.
    #
    # @example YAML object
    #   - type: polygon_outline
    #     points:
    #       - [120, 740]
    #       - [340, 610]
    #       - [450, 820]
    #       - [250, 980]
    #     stroke_width: 12
    #     color: green
    # @return [void]
    def draw_polygon_outline_object(page, object, layout, style:, brush:)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      points = resolve_points(layout, object.fetch("points") { raise ArgumentError, "points are required" })
      Shapes.polygon_outline(page, points, stroke_width, brush:, **style)
    end

    # Draws a regular polygon outline object fitted into its box.
    #
    # @return [void]
    def draw_regular_polygon_outline_object(page, object, layout, style:, brush:)
      box = resolve_square_fit_box(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      sides = fetch_number(object, "sides").to_i
      rotation = resolve_regular_polygon_rotation(object, sides)
      radius = [box[:width], box[:height]].min / 2.0
      Shapes.regular_polygon_outline(page, box[:center_x], box[:center_y], radius, sides, stroke_width, rotation:, brush:, **style)
    end

    # Draws a filled regular polygon object fitted into its box.
    #
    # @return [void]
    def draw_regular_polygon_fill_object(page, object, layout, style:, brush:)
      box = resolve_square_fit_box(layout, object)
      sides = fetch_number(object, "sides").to_i
      rotation = resolve_regular_polygon_rotation(object, sides)
      radius = [box[:width], box[:height]].min / 2.0
      colors = object.key?("colors") ? parse_color_list(object["colors"]) : [style[:color] == RmPage::Colour::RGBA ? style[:rgba] : style[:color]]
      Shapes.regular_polygon_fill(page, box[:center_x], box[:center_y], radius, sides, colors:, rotation:, brush:)
    end

    # Draws a regular polygon with separate fill and outline styles.
    #
    # @return [void]
    def draw_regular_polygon_outline_fill_object(page, object, layout, brush:)
      draw_regular_polygon_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_regular_polygon_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a parallelogram from four local points.
    #
    # @return [void]
    def draw_parallelogram_object(page, object, layout, style:, brush:)
      points = resolve_points(layout, object.fetch("points") { raise ArgumentError, "points are required" })
      raise ArgumentError, "parallelogram requires exactly 4 points" unless points.length == 4

      Shapes.parallelogram(page, points[0], points[1], points[2], points[3], brush:, **style)
    end

    # Draws text into a box with optional wrapping and alignment.
    #
    # @example YAML object
    #   - type: text
    #     x: 40
    #     y: 20
    #     width: 1120
    #     height: 220
    #     text: "remarkable-shapes\nWrapped text and image pixel_gap example"
    #     size: 62
    #     stroke_width: 5
    #     wrap: true
    #     align: center
    #     valign: center
    #     color: black
    # @return [void]
    def draw_text_object(page, object, layout, style:, brush:)
      draw_text_like_object(page, object, layout, style:, brush:, shadow: false)
    end

    # Draws shadowed text into a box with optional wrapping and alignment.
    #
    # @return [void]
    def draw_shadow_text_object(page, object, layout, style:, brush:)
      draw_text_like_object(page, object, layout, style:, brush:, shadow: true)
    end

    # Draws text-like objects into a box with optional wrapping and alignment.
    #
    # @return [void]
    def draw_text_like_object(page, object, layout, style:, brush:, shadow:)
      box = resolve_box(layout, object)
      text = object.fetch("text") { raise ArgumentError, "text is required" }.to_s
      size = scale_length(layout, fetch_number(object, "size", LineFont::DEFAULT_SIZE))
      stroke_width = scale_length(layout, fetch_number(object, "stroke_width", LineFont::DEFAULT_STROKE_WIDTH))
      line_spacing = fetch_number(object, "line_spacing", 1.25)
      style_name = object.fetch("style", LineFont::DEFAULT_STYLE).to_sym
      font_name = object.fetch("font", LineFont::DEFAULT_FONT).to_sym
      mono = object.fetch("mono", false)
      wrap = object.fetch("wrap", false)
      align = object.fetch("align", "left").to_s
      valign = object.fetch("valign", "top").to_s
      shadow_dx = shadow ? scale_length(layout, fetch_number(object, "shadow_dx", 0.0)) : 0.0
      shadow_dy = shadow ? scale_length(layout, fetch_number(object, "shadow_dy", 0.0)) : 0.0
      shadow_style = shadow ? shadow_style_options_for(object) : nil
      shadow_brush = shadow && object.key?("shadow_brush") ? brush_for(object["shadow_brush"]) : brush

      lines = if wrap
                wrap_text_lines(text, box[:width] - shadow_dx.abs, size:, style: style_name, font: font_name, mono:)
              else
                text.split("\n", -1)
              end

      line_height = size * line_spacing
      block_height = line_height * [lines.length, 1].max
      rendered_block_height = block_height + shadow_dy.abs
      top_y =
        case valign
        when "top"
          box[:y] - [shadow_dy, 0.0].min
        when "center", "middle"
          box[:y] + ((box[:height] - rendered_block_height) / 2.0) - [shadow_dy, 0.0].min
        when "bottom"
          box[:y] + (box[:height] - rendered_block_height) - [shadow_dy, 0.0].min
        else
          raise ArgumentError, "unsupported valign: #{valign}"
        end

      baseline = top_y - LineFont.baseline_to_top(size)
      lines.each do |line|
        line_width = LineFont.text_width(line, size:, style: style_name, font: font_name, mono:)
        rendered_line_width = line_width + shadow_dx.abs
        x =
          case align
          when "left"
            box[:x] - [shadow_dx, 0.0].min
          when "center", "middle"
            box[:x] + ((box[:width] - rendered_line_width) / 2.0) - [shadow_dx, 0.0].min
          when "right"
            box[:x] + (box[:width] - rendered_line_width) - [shadow_dx, 0.0].min
          else
            raise ArgumentError, "unsupported align: #{align}"
          end

        if shadow
          Shapes.shadow_text(
            page,
            line,
            x,
            baseline,
            size:,
            stroke_width:,
            style: style_name,
            font: font_name,
            mono:,
            shadow_dx:,
            shadow_dy:,
            shadow_brush:,
            **shadow_style,
            brush:,
            **style
          )
        else
          Shapes.text(
            page,
            line,
            x,
            baseline,
            size:,
            stroke_width:,
            style: style_name,
            font: font_name,
            mono:,
            brush:,
            **style
          )
        end
        baseline += line_height
      end
    end

    # Draws an image object fitted inside the given bounding box.
    #
    # @example YAML object
    #   - type: image
    #     path: cat.png
    #     x: 320
    #     y: 250
    #     width: 560
    #     height: 500
    #     pixel_gap: -0.10
    # @return [void]
    def draw_image_object(page, object, layout, base_dir:, brush:)
      box = resolve_box(layout, object)
      image_path = File.expand_path(object.fetch("path") { raise ArgumentError, "image path is required" }, base_dir)
      rgba_grid = Shapes.png_to_rgba_grid(image_path)
      image_height = rgba_grid.length
      image_width = rgba_grid.first&.length.to_i
      raise ArgumentError, "image PNG must not be empty" if image_width <= 0

      pixel_size = [box[:width] / image_width.to_f, box[:height] / image_height.to_f].min
      grid_width = image_width * pixel_size
      grid_height = image_height * pixel_size
      placement = (object["placement"] || "center").to_s
      fitted_box = place_box_in_box(box, grid_width, grid_height, placement)
      pixel_gap = fetch_number(object, "pixel_gap", -3.0)

      Shapes.draw_rgba_grid(page, rgba_grid, fitted_box[:x], fitted_box[:y], pixel_size, gap: pixel_gap, brush:)
    end

    # Draws a nested YAML object by fitting its child canvas into the box.
    #
    # @example YAML object
    #   - type: yaml
    #     path: nested-child.yml
    #     x: 220
    #     y: 320
    #     width: 900
    #     height: 1200
    # @return [void]
    def draw_yaml_object(page, object, layout, base_dir:)
      yaml_path = File.expand_path(object.fetch("path") { raise ArgumentError, "yaml path is required" }, base_dir)
      child_config = load_file_config(yaml_path)
      child_layout = nested_layout_for(layout, object, child_config)
      render(
        page,
        child_config,
        base_dir: File.dirname(yaml_path),
        layout_override: child_layout
      )
    end
  end
end
