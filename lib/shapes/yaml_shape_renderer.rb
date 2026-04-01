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

    module_function

    # Loads a YAML file and renders it onto the page.
    #
    # @param page [Remarkable::RmPage]
    # @param yaml_path [String]
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

      objects.each do |object|
        render_object(page, stringify_keys(object), layout, base_dir:)
      end

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

      {
        x:,
        y:,
        width:,
        height:,
        placement:,
        tablet: profile.fetch(:tablet),
        physical_width: profile.fetch(:physical_width),
        physical_height: profile.fetch(:physical_height),
        scale: 1.0
      }
    end

    # Resolves an object's local bounding box into page coordinates.
    #
    # @return [Hash]
    def resolve_box(layout, object)
      x = map_x(layout, fetch_number(object, "x"))
      y = map_y(layout, fetch_number(object, "y"))
      width = scale_length(layout, fetch_number(object, "width"))
      height = scale_length(layout, fetch_number(object, "height"))
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
    def render_object(page, object, layout, base_dir:)
      type = object.fetch("type") { raise ArgumentError, "object type is required" }.to_s
      style = style_options_for(object)
      brush = brush_for(object["brush"])

      case type
      when "line"
        draw_line_object(page, object, layout, style:, brush:)
      when "circle_fill"
        draw_circle_fill_object(page, object, layout, style:, brush:)
      when "circle_outline"
        draw_circle_outline_object(page, object, layout, style:, brush:)
      when "circle_outline_fill"
        draw_circle_outline_fill_object(page, object, layout, brush:)
      when "rectangle_fill"
        draw_rectangle_fill_object(page, object, layout, style:, brush:)
      when "rectangle_outline"
        draw_rectangle_outline_object(page, object, layout, style:, brush:)
      when "rectangle_outline_fill"
        draw_rectangle_outline_fill_object(page, object, layout, brush:)
      when "star"
        draw_star_object(page, object, layout, style:, brush:)
      when "polygon_outline"
        draw_polygon_outline_object(page, object, layout, style:, brush:)
      when "regular_polygon_outline"
        draw_regular_polygon_outline_object(page, object, layout, style:, brush:)
      when "regular_polygon_fill"
        draw_regular_polygon_fill_object(page, object, layout, style:, brush:)
      when "parallelogram"
        draw_parallelogram_object(page, object, layout, style:, brush:)
      when "text"
        draw_text_object(page, object, layout, style:, brush:)
      when "image"
        draw_image_object(page, object, layout, base_dir:, brush:)
      when "yaml"
        draw_yaml_object(page, object, layout, base_dir:)
      else
        raise ArgumentError, "unsupported object type: #{type}"
      end
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
    def wrap_text_lines(text, max_width, size:, style:, mono:)
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
          if LineFont.text_width(candidate, size:, style:, mono:) <= max_width || current.empty?
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

      {
        x: box[:x] + ((box[:width] - target_width) / 2.0),
        y: box[:y] + ((box[:height] - target_height) / 2.0),
        width: child_canvas[:width],
        height: child_canvas[:height],
        placement: "nested",
        tablet: child_canvas[:tablet],
        physical_width: parent_layout[:physical_width],
        physical_height: parent_layout[:physical_height],
        scale:
      }
    end

    # Draws a line object.
    #
    # @return [void]
    def draw_line_object(page, object, layout, style:, brush:)
      x1 = map_x(layout, fetch_number(object, "x1"))
      y1 = map_y(layout, fetch_number(object, "y1"))
      x2 = map_x(layout, fetch_number(object, "x2"))
      y2 = map_y(layout, fetch_number(object, "y2"))
      width = scale_length(layout, fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH))
      Shapes.draw_line(page, x1, y1, x2, y2, width, brush:, **style)
    end

    # Draws a filled circle object.
    #
    # @return [void]
    def draw_circle_fill_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      radius = [box[:width], box[:height]].min / 2.0
      Shapes.circle(page, box[:center_x], box[:center_y], radius, brush:, **style)
    end

    # Draws a circle outline object.
    #
    # @return [void]
    def draw_circle_outline_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      radius = ([box[:width], box[:height]].min - stroke_width) / 2.0
      raise ArgumentError, "circle outline is too small for its stroke width" unless radius.positive?

      steps = 40
      points = Array.new(steps + 1) do |index|
        angle = (2.0 * Math::PI * index) / steps
        [
          box[:center_x] + (radius * Math.cos(angle)),
          box[:center_y] + (radius * Math.sin(angle))
        ]
      end
      Shapes.draw_polyline(page, points, stroke_width, brush:, **style)
    end

    # Draws a circle with separate fill and outline styles.
    #
    # @return [void]
    def draw_circle_outline_fill_object(page, object, layout, brush:)
      draw_circle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_circle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a filled rectangle object.
    #
    # @return [void]
    def draw_rectangle_fill_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      Shapes.rect(page, box[:x], box[:center_y], box[:x] + box[:width], box[:center_y], box[:height], brush:, **style)
    end

    # Draws a rectangle outline object.
    #
    # @return [void]
    def draw_rectangle_outline_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      Shapes.draw_box(page, box[:x], box[:y], box[:x] + box[:width], box[:y] + box[:height], stroke_width, brush:, **style)
    end

    # Draws a rectangle with separate fill and outline styles.
    #
    # @return [void]
    def draw_rectangle_outline_fill_object(page, object, layout, brush:)
      draw_rectangle_fill_object(page, object, layout, style: style_options_for(object, "fill"), brush:)
      draw_rectangle_outline_object(page, object, layout, style: style_options_for(object, "outline"), brush:)
    end

    # Draws a star object using one or more cycled colours.
    #
    # @return [void]
    def draw_star_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      point_count = fetch_number(object, "points").to_i
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
      box = resolve_box(layout, object)
      stroke_width = fetch_number(object, "stroke_width", DEFAULT_STROKE_WIDTH)
      sides = fetch_number(object, "sides").to_i
      rotation = fetch_number(object, "rotation", 0.0)
      radius = [box[:width], box[:height]].min / 2.0
      Shapes.regular_polygon_outline(page, box[:center_x], box[:center_y], radius, sides, stroke_width, rotation:, brush:, **style)
    end

    # Draws a filled regular polygon object fitted into its box.
    #
    # @return [void]
    def draw_regular_polygon_fill_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      sides = fetch_number(object, "sides").to_i
      rotation = fetch_number(object, "rotation", 0.0)
      radius = [box[:width], box[:height]].min / 2.0
      colors = object.key?("colors") ? parse_color_list(object["colors"]) : [style[:color] == RmPage::Colour::RGBA ? style[:rgba] : style[:color]]
      Shapes.regular_polygon_fill(page, box[:center_x], box[:center_y], radius, sides, colors:, rotation:, brush:)
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
    # @return [void]
    def draw_text_object(page, object, layout, style:, brush:)
      box = resolve_box(layout, object)
      text = object.fetch("text") { raise ArgumentError, "text is required" }.to_s
      size = scale_length(layout, fetch_number(object, "size", LineFont::DEFAULT_SIZE))
      stroke_width = scale_length(layout, fetch_number(object, "stroke_width", LineFont::DEFAULT_STROKE_WIDTH))
      line_spacing = fetch_number(object, "line_spacing", 1.25)
      style_name = object.fetch("style", LineFont::DEFAULT_STYLE).to_sym
      mono = object.fetch("mono", false)
      wrap = object.fetch("wrap", false)
      align = object.fetch("align", "left").to_s
      valign = object.fetch("valign", "top").to_s

      lines = if wrap
                wrap_text_lines(text, box[:width], size:, style: style_name, mono:)
              else
                text.split("\n", -1)
              end

      line_height = size * line_spacing
      block_height = line_height * [lines.length, 1].max
      top_y = case valign
              when "top"
                box[:y]
              when "center", "middle"
                box[:y] + ((box[:height] - block_height) / 2.0)
              when "bottom"
                box[:y] + (box[:height] - block_height)
              else
                raise ArgumentError, "unsupported valign: #{valign}"
              end

      baseline = top_y - LineFont.baseline_to_top(size)
      lines.each do |line|
        line_width = LineFont.text_width(line, size:, style: style_name, mono:)
        x = case align
            when "left"
              box[:x]
            when "center", "middle"
              box[:x] + ((box[:width] - line_width) / 2.0)
            when "right"
              box[:x] + (box[:width] - line_width)
            else
              raise ArgumentError, "unsupported align: #{align}"
            end

        Shapes.text(
          page,
          line,
          x,
          baseline,
          size:,
          stroke_width:,
          style: style_name,
          mono:,
          brush:,
          **style
        )
        baseline += line_height
      end
    end

    # Draws an image object fitted inside the given bounding box.
    #
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
      x = box[:x] + ((box[:width] - grid_width) / 2.0)
      y = box[:y] + ((box[:height] - grid_height) / 2.0)
      pixel_gap = if object.key?("gap")
                    fetch_number(object, "gap", 0.0)
                  else
                    fetch_number(object, "pixel_gap", 0.0)
                  end

      Shapes.draw_rgba_grid(page, rgba_grid, x, y, pixel_size, gap: pixel_gap, brush:)
    end

    # Draws a nested YAML object by fitting its child canvas into the box.
    #
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
