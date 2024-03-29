# Title: Jekyll Image Tag
# Authors: Rob Wierzbowski : @robwierzbowski
#
# Description: Better images for Jekyll.
#
# Download: https://github.com/robwierzbowski/jekyll-image-tag
# Documentation: https://github.com/robwierzbowski/jekyll-image-tag/readme.md
# Issues: https://github.com/robwierzbowski/jekyll-image-tag/issues
#
# Syntax:  {% image [preset or WxH] path/to/img.jpg [attr="value"] %}
# Example: {% image poster.jpg alt="The strange case of Dr. Jekyll" %}
#          {% image gallery poster.jpg alt="The strange case of Dr. Jekyll" class="gal-img" data-selected %}
#          {% image 350xAUTO poster.jpg alt="The strange case of Dr. Jekyll" class="gal-img" data-selected %}
#
# See the documentation for full configuration and usage instructions.

require 'fileutils'
require 'pathname'
require 'digest/md5'
require 'mini_magick'
require 'uri'

module Jekyll

  class Image < Liquid::Tag

    def initialize(tag_name, markup, tokens)
      @markup = markup
      super
    end

    def render(context)

      # Render any liquid variables in tag arguments and unescape template code
      render_markup = Liquid::Template.parse(@markup).render(context).gsub(/\\\{\\\{|\\\{\\%/, '\{\{' => '{{', '\{\%' => '{%')

      # Gather settings
      site = context.registers[:site]
      settings = site.config['image']
      markup = /^(?:(?<preset>[^\s.:\/]+)\s+)?\"(?<image_src>[^\"]+\.[a-zA-Z0-9]{3,4})\"\s*(?<html_attr>[\s\S]+)?$/.match(render_markup)
      puts markup.inspect
      preset = settings['presets'][ markup[:preset] ]

      raise "Image Tag can't read this tag. Try {% image [preset or WxH] path/to/img.jpg [attr=\"value\"] %}." unless markup

      # Assign defaults
      settings['source'] ||= '.'
      settings['output'] ||= 'generated'
      settings['wrapperTag'] ||= 'div'

      # Prevent Jekyll from erasing our generated files
      site.config['keep_files'] << settings['output'] unless site.config['keep_files'].include?(settings['output'])

      # Process instance
      instance = if preset
        {
          :width => preset['width'],
          :height => preset['height'],
          :src => markup[:image_src]
        }
      elsif dim = /^(?:(?<width>\d+)|auto)(?:x)(?:(?<height>\d+)|auto)$/i.match(markup[:preset])
        {
          :width => dim['width'],
          :height => dim['height'],
          :src => markup[:image_src]
        }
      else
        {
          :width => nil,
          :height => nil,
          :src => markup[:image_src]
        }
      end

      # Process html attributes
      html_attr = if markup[:html_attr]
        Hash[ *markup[:html_attr].scan(/(?<attr>[^\s="]+)(?:="(?<value>[^"]+)")?\s?/).flatten ]
      else
        {}
      end

      if preset && preset['attr']
        html_attr = preset['attr'].merge(html_attr)
      end

      html_attr_string = html_attr.inject('') { |string, attrs|
        if attrs[0].downcase != 'href'
          if attrs[1] and attrs[0]
            string << "#{attrs[0]}=\"#{attrs[1]}\" "
          else
            string << "#{attrs[0]} "
          end
        end
      }

      # Get the post's title so we can place generated images in a subfolder
      if context.registers[:site].posts and context["page"]["id"]
        id = context["page"]["id"]
        posts = context.registers[:site].posts
        post = posts [posts.index {|post| post.id == id}]
        post_slug = (Pathname.new post.url).basename
      else
        post_slug = ""
      end

      if post_slug != ""
        puts post_slug
      else
        puts "Processing some template file"
      end

      # Raise some exceptions before we start expensive processing
      raise "Image Tag can't find the \"#{markup[:preset]}\" preset. Check image: presets in _config.yml for a list of presets." unless preset || dim ||  markup[:preset].nil?

      # Hack for easy 2x images
      instance_0x = Marshal.load( Marshal.dump(instance) )
      instance_2x = Marshal.load( Marshal.dump(instance) )

      if instance[:width] || instance[:height]
        generated_src = URI.escape( generate_image(instance, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
        # Calculate 0x resolution
        instance_0x[:width] = (instance[:width].to_f / 2).round
        instance_0x[:height] = (instance[:height].to_f / 2).round
        generated_src_0x = URI.escape( generate_image(instance_0x, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
        # Calculate 2x resolution
        instance_2x[:width] = (instance[:width].to_f * 2).round
        instance_2x[:height] = (instance[:height].to_f * 2).round
        generated_src_2x = URI.escape( generate_image(instance_2x, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
      else
        # Generate the 2x image at full resolution
        generated_src_2x = URI.escape( generate_image(instance_2x, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
        # Generate a 1x image that's half the size of the 2x image
        instance[:width] = (instance_2x[:width].to_f / 2).round
        instance[:height] = (instance_2x[:height].to_f / 2).round
        generated_src = URI.escape( generate_image(instance, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
        # Generate a 0x image that's a quarter of the size of the 2x image
        instance_0x[:width] = (instance_2x[:width].to_f / 4).round
        instance_0x[:height] = (instance_2x[:height].to_f / 4).round
        generated_src_0x = URI.escape( generate_image(instance, site.source, site.dest, settings['source'], File.join(settings['output'], post_slug) ).to_s )
      end

      unless generated_src && generated_src_0x && generated_src_2x
        return
      end

      baseURL = Jekyll.configuration({})['baseurl']

      # Build the output HTML
      output = "<#{settings['wrapperTag']} class=\"img-container #{markup[:preset]}\" style=\"padding-bottom: #{instance[:container_padding]}%;\">"
      if html_attr["href"]
        output += "<a href=\"#{html_attr["href"]}\">"
      end
      output += "<img src=\"#{baseURL}#{generated_src}\" srcset=\"#{baseURL}#{generated_src} #{(instance[:width] * 3/4).round}w, #{baseURL}#{generated_src} #{(instance[:width] * 3/4).round}w 2x, #{baseURL}#{generated_src_2x} 2x, #{baseURL}#{generated_src}\" #{html_attr_string} width=\"#{instance[:width]}\" height=\"#{instance[:height]}\">"
      if html_attr["href"]
        output += "</a>"
      end
      output += "</#{settings['wrapperTag']}>"
      # Actually yield the output, yay
      output
    end

    def generate_image(instance, site_source, site_dest, image_source, image_dest)

      if (Pathname.new instance[:src]).absolute?
        image_source_path = File.join(instance[:src])
      else
        image_source_path = File.join(site_source, image_source, instance[:src])
      end
      unless File.exists?image_source_path
        puts "Missing: #{image_source_path}"
        return false
      end

      image = MiniMagick::Image.open(image_source_path)
      digest = Digest::MD5.hexdigest(image.to_blob).slice!(0..5)

      image_dir = File.dirname(instance[:src])
      ext = File.extname(instance[:src])
      basename = File.basename(instance[:src], ext)

      orig_width = image[:width].to_f
      orig_height = image[:height].to_f
      orig_ratio = orig_width/orig_height

      gen_width = if instance[:width] and instance[:width].to_f > 0
        instance[:width].to_f
      elsif instance[:height]
        orig_ratio * instance[:height].to_f
      else
        orig_width
      end
      gen_height = if instance[:height] and instance[:height].to_f > 0
        instance[:height].to_f
      elsif instance[:width]
        instance[:width].to_f / orig_ratio
      else
        orig_height
      end
      gen_ratio = gen_width/gen_height

      # Don't allow upscaling. If the image is smaller than the requested dimensions, recalculate.
      if orig_width < gen_width || orig_height < gen_height
        undersize = true
        gen_width = if orig_ratio < gen_ratio then orig_width else orig_height * gen_ratio end
        gen_height = if orig_ratio > gen_ratio then orig_height else orig_width/gen_ratio end
      end

      gen_name = "#{basename}-#{gen_width.round}x#{gen_height.round}-#{digest}#{ext}"
      gen_dest_dir = File.join(site_dest, image_dest)
      gen_dest_file = File.join(gen_dest_dir, gen_name)

      # Generate resized files
      unless File.exists?(gen_dest_file)

        warn "Warning:".yellow + " #{instance[:src]} is smaller than the requested output file. It will be resized without upscaling." if undersize

        #  If the destination directory doesn't exist, create it
        FileUtils.mkdir_p(gen_dest_dir) unless File.exist?(gen_dest_dir)

        # Let people know their images are being generated
        puts "Generating #{gen_name}"

        # Scale and crop
        image.combine_options do |i|
          i.resize "#{gen_width}x#{gen_height}^"
          i.gravity "center"
          i.crop "#{gen_width}x#{gen_height}+0+0"
        end

        image.write gen_dest_file
      end

      # Update instance with actual dimensions used
      instance[:width] = gen_width.to_i
      instance[:height] = gen_height.to_i
      instance[:ratio] = gen_ratio
      instance[:container_padding] = (1 / gen_ratio.to_f * 100)

      # Return path relative to the site root for html
      Pathname.new(File.join('/', image_dest, gen_name)).cleanpath
    end
  end
end

Liquid::Template.register_tag('image', Jekyll::Image)
