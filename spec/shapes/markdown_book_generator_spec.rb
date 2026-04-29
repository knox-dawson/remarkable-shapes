# frozen_string_literal: true

require "tmpdir"
require "yaml"

require_relative "../spec_helper"
require "shapes/markdown_book_generator"

RSpec.describe Remarkable::MarkdownBookGenerator do
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

  it "builds paginated yaml and rmdoc output from markdown" do
    Dir.mktmpdir do |dir|
      markdown_path = File.join(dir, "notes.md")
      config_path = File.join(dir, "markdown.yml")
      output_dir = File.join(dir, "build")
      final_output = File.join(dir, "notes.rmdoc")
      fake_rmcat = File.join(dir, "rmcat")

      File.write(
        markdown_path,
        <<~MARKDOWN
          # Title

          This is a paragraph that should wrap into multiple lines inside the markdown book generator.

          This paragraph includes inline `code span` to prove the monospace style is used for backtick text.

          - first bullet
          - second bullet

          > quoted text
          > It's quoted text

          ---

          ```
          code sample
          ```
        MARKDOWN
      )
      File.write(
        config_path,
        {
          "styles" => {
            "blockquote" => {
              "prefix" => "<< "
            }
          }
        }.to_yaml
      )
      write_fake_rmcat(fake_rmcat)

      result = described_class.generate_from_markdown(
        markdown_path:,
        config_path:,
        output_dir:,
        final_output:,
        rmcat_command: fake_rmcat,
        run_concat: true
      )

      expect(result[:generated_yaml_paths]).not_to be_empty
      expect(result[:rmdoc_paths]).not_to be_empty
      expect(File.file?(final_output)).to be(true)

      generated_pages = result[:generated_yaml_paths].map { |path| YAML.safe_load(File.read(path)) }
      objects = generated_pages.flat_map { |page| page.fetch("objects") }
      text_values = objects.select { |object| object["type"] == "text" }.map { |object| object["text"] }

      expect(text_values).to include("Title")
      expect(text_values).to include("- first bullet")
      expect(text_values).to include("<< quoted text")
      expect(text_values).to include("It’s quoted text")
      expect(objects.any? { |object| object["type"] == "text" && object["text"] == "code span" && object["font"] == "noto_lines_mono_filled" }).to be(true)
      expect(objects.any? { |object| object["type"] == "text" && object["text"] == "code sample" && object["font"] == "noto_lines_mono_filled" }).to be(true)
      expect(objects.any? { |object| object["type"] == "line" }).to be(true)
    end
  end

  it "renders italic, bold, and bold italic inline markdown" do
    Dir.mktmpdir do |dir|
      markdown_path = File.join(dir, "emphasis.md")
      output_dir = File.join(dir, "build")
      final_output = File.join(dir, "emphasis.rmdoc")
      fake_rmcat = File.join(dir, "rmcat")

      File.write(
        markdown_path,
        <<~MARKDOWN
          Normal paragraph.

          *italic*

          **bold**

          ***bold italic***
        MARKDOWN
      )
      write_fake_rmcat(fake_rmcat)

      result = described_class.generate_from_markdown(
        markdown_path:,
        output_dir:,
        final_output:,
        rmcat_command: fake_rmcat,
        run_concat: true
      )

      generated_pages = result[:generated_yaml_paths].map { |path| YAML.safe_load(File.read(path)) }
      objects = generated_pages.flat_map { |page| page.fetch("objects") }
      text_objects = objects.select { |object| object["type"] == "text" }
      body_style = text_objects.find { |object| object["text"] == "Normal paragraph." }
      italic = text_objects.find { |object| object["text"] == "italic" }
      bold = text_objects.find { |object| object["text"] == "bold" }
      bold_italic = text_objects.find { |object| object["text"] == "bold italic" }

      expect(body_style).not_to be_nil
      expect(italic).not_to be_nil
      expect(bold).not_to be_nil
      expect(bold_italic).not_to be_nil
      expect(italic.fetch("font")).to eq("noto_lines_sans_italic_filled")
      expect(bold.fetch("stroke_width")).to be > body_style.fetch("stroke_width")
      expect(bold_italic.fetch("font")).to eq("noto_lines_sans_italic_filled")
      expect(bold_italic.fetch("stroke_width")).to be > body_style.fetch("stroke_width")
    end
  end

  it "merges a partial config override and paginates long markdown across multiple pages" do
    Dir.mktmpdir do |dir|
      markdown_path = File.join(dir, "long.md")
      config_path = File.join(dir, "markdown.yml")
      output_dir = File.join(dir, "build")
      final_output = File.join(dir, "long.rmdoc")
      fake_rmcat = File.join(dir, "rmcat")

      File.write(markdown_path, ([("Long paragraph " * 12).strip] * 40).join("\n\n"))
      File.write(
        config_path,
        {
          "page" => {
            "bottom" => 520
          },
          "styles" => {
            "body" => {
              "font" => "relief_singleline",
              "size" => 22
            }
          }
        }.to_yaml
      )
      write_fake_rmcat(fake_rmcat)

      result = described_class.generate_from_markdown(
        markdown_path:,
        config_path:,
        output_dir:,
        final_output:,
        rmcat_command: fake_rmcat,
        run_concat: true
      )

      expect(result[:generated_yaml_paths].length).to be > 1
      generated_yaml = YAML.safe_load(File.read(result[:generated_yaml_paths].first))
      first_text = generated_yaml.fetch("objects").find { |object| object["type"] == "text" }
      expect(first_text.fetch("font")).to eq("relief_singleline")
      expect(first_text.fetch("size")).to eq(22)
    end
  end

  it "writes the default markdown config template" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "markdown-defaults.yml")

      described_class.write_default_config(path)

      expect(File.file?(path)).to be(true)
      yaml = YAML.safe_load(File.read(path))
      expect(yaml.fetch("styles").fetch("body").fetch("font")).to eq("noto_lines_sans_filled")
      expect(yaml.fetch("elements").fetch("paragraph").fetch("style")).to eq("body")
    end
  end
end
