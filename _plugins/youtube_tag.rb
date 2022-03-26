# Based on https://gist.github.com/joelverhagen/1805814

class YouTube < Liquid::Tag
  Syntax = /^\s*(https:\/\/youtube.com\/)?([^\s]+)(?:\s+(\d+)\s+(\d+)\s*)?/

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
      raise "No YouTube ID provided in the \"youtube\" tag"
    end
  end

  def render(context)
    "<div class=\"video-container vimeo\"><iframe width=\"#{@width}\" height=\"#{@height}\" src=\"https://www.youtube-nocookie.com/embed/#{@id}?modestbranding=1\" frameborder=\"0\" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe></div>"
  end

  Liquid::Template.register_tag "youtube", self
end
