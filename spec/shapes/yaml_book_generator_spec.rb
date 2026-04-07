# frozen_string_literal: true

require "tmpdir"
require "yaml"

require_relative "../spec_helper"
require "shapes/yaml_book_generator"

RSpec.describe Remarkable::YamlBookGenerator do
  def write_simple_yaml(path, text)
    File.write(
      path,
      <<~YAML
        canvas:
          width: 300
          height: 220
          placement: top-left
        objects:
          - type: text
            x: 20
            y: 20
            width: 240
            height: 80
            text: #{text.to_yaml.strip}
            size: 24
            stroke_width: 2
            color: black
      YAML
    )
  end

  def write_fake_rmcat(path)
    File.write(
      path,
      <<~BASH
        #!/usr/bin/env bash
        set -euo pipefail
        output="$2"
        shift 2
        cat "$@" > "$output"
      BASH
    )
    FileUtils.chmod(0o755, path)
  end

  it "builds a multipage rmdoc from an ordered yaml page list" do
    Dir.mktmpdir do |dir|
      cover_yaml = File.join(dir, "cover.yml")
      page_yaml = File.join(dir, "page.yml")
      list_yaml = File.join(dir, "pages.yml")
      output_dir = File.join(dir, "build")
      final_output = File.join(dir, "book.rmdoc")
      fake_rmcat = File.join(dir, "rmcat")

      write_simple_yaml(cover_yaml, "Cover")
      write_simple_yaml(page_yaml, "Page 1")
      File.write(list_yaml, { "pages" => [cover_yaml, page_yaml] }.to_yaml)
      write_fake_rmcat(fake_rmcat)

      result = described_class.generate_from_yaml_list(
        list_path: list_yaml,
        output_dir:,
        final_output:,
        rmcat_command: fake_rmcat,
        run_concat: true
      )

      expect(result[:yaml_paths]).to eq([cover_yaml, page_yaml].map { |path| File.expand_path(path) })
      expect(result[:rmdoc_paths].length).to eq(2)
      expect(result[:rmdoc_paths]).to all(satisfy { |path| File.file?(path) })
      expect(File.file?(result[:concat_script_path])).to be(true)
      expect(File.file?(final_output)).to be(true)
      expect(result[:concat_ran]).to be(true)
    end
  end

  it "builds templated pages from items and a cover yaml" do
    Dir.mktmpdir do |dir|
      cover_yaml = File.join(dir, "cover.yml")
      template_yaml = File.join(dir, "template.yml")
      items_yaml = File.join(dir, "items.yml")
      output_dir = File.join(dir, "build")
      final_output = File.join(dir, "catalog.rmdoc")
      fake_rmcat = File.join(dir, "rmcat")
      image_a = File.join(dir, "alpha-01.png")
      image_b = File.join(dir, "beta-02.png")

      write_simple_yaml(cover_yaml, "Catalog Cover")
      ChunkyPNG::Image.new(2, 2, ChunkyPNG::Color.rgba(255, 0, 0, 255)).save(image_a)
      ChunkyPNG::Image.new(2, 2, ChunkyPNG::Color.rgba(0, 0, 255, 255)).save(image_b)
      File.write(
        template_yaml,
        <<~YAML
          canvas:
            width: 400
            height: 300
            placement: top-left
            grid:
              size: 2x2
              cell_padding: 10
          slots:
            - image_cell: 1
              label_cell: 3
            - image_cell: 2
              label_cell: 4
          template:
            - type: image
              cell: "{{image_cell}}"
              path: "{{image}}"
            - type: text
              cell: "{{label_cell}}"
              text: "{{label}}"
              size: 20
              stroke_width: 2
              align: center
              valign: center
              color: black
        YAML
      )
      File.write(
        items_yaml,
        {
          "items" => [
            { "image" => image_a, "label" => "Alpha" },
            { "image" => image_b, "match" => ".*/([a-z]+)-(\\d+)\\.png$" }
          ]
        }.to_yaml
      )
      write_fake_rmcat(fake_rmcat)

      result = described_class.generate_from_template(
        cover_yaml:,
        template_yaml:,
        items_yaml:,
        output_dir:,
        final_output:,
        prefix: "catalog",
        rmcat_command: fake_rmcat,
        run_concat: true
      )

      expect(result[:generated_yaml_paths].length).to eq(1)
      generated_yaml = File.read(result[:generated_yaml_paths].first)
      expect(generated_yaml).to include("text: Alpha")
      expect(generated_yaml).to include("text: beta 02")
      expect(generated_yaml).to include('path: "../../alpha-01.png"')
      expect(result[:rmdoc_paths].length).to eq(2)
      expect(File.file?(final_output)).to be(true)
      expect(result[:concat_ran]).to be(true)
    end
  end
end
