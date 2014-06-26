# Based on https://gist.github.com/joelverhagen/1805814

class Vimeo < Liquid::Tag
  Syntax = /^\s*(http:\/\/vimeo.com\/)?([^\s]+)(?:\s+(\d+)\s+(\d+)\s*)?/

  def initialize(tagName, markup, tokens)
    super

    if markup =~ Syntax then
      @id = $2

      if $3.nil? then
          @width = 960
          @height = 540
      else
          @width = $3.to_i
          @height = $4.to_i
      end
    else
      raise "No Vimeo ID provided in the \"vimeo\" tag"
    end
  end

  def render(context)
    "<div class=\"video-container vimeo\"><iframe width=\"#{@width}\" height=\"#{@height}\" src=\"//player.vimeo.com/video/#{@id}?portrait=0&title=0&byline=0\" frameborder=\"0\" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe></div>"
  end

  Liquid::Template.register_tag "vimeo", self
end
