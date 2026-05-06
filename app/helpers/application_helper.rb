module ApplicationHelper
  include MarkdownHelper

  def flash_bootstrap_class(type)
    { "notice" => "success", "alert" => "danger", "info" => "info", "warning" => "warning" }
      .fetch(type.to_s, "secondary")
  end

  # Parses the labeled-block user_input format used by DiscoveryStep.
  # Input format: "FIELD:key\nvalue\n---\nFIELD:key2\nvalue2"
  # Returns a symbol-keyed hash: { key: "value", key2: "value2" }
  def parse_step_input(input)
    return {} if input.blank?
    input.split("\n---\n").each_with_object({}) do |block, hash|
      lines = block.strip.split("\n", 2)
      key   = lines[0].sub("FIELD:", "").strip
      value = lines[1]&.strip || ""
      hash[key.to_sym] = value
    end
  end
end
