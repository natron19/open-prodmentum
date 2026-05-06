module MarkdownHelper
  def render_markdown(text)
    return "" if text.blank?
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true)
    markdown = Redcarpet::Markdown.new(renderer,
      tables: true, autolink: true, fenced_code_blocks: true,
      strikethrough: true, no_intra_emphasis: true)
    raw markdown.render(text)
  end
end
