module ActionView
  class PathSet
    # for Mime::Type instances, this does exactly the same as the Rails (2.3.2) version.
    # for Dynamime::Type instances, it will try to find a template for the format's parents
    # if no template for the requested format is found.
    alias :find_template_without_dynamime :find_template
    def find_template(original_template_path, format = nil, html_fallback = true, depth = 0)
      debug_message "find_template(#{original_template_path}, #{format.inspect}, #{html_fallback}, #{depth})"
      mime_type = Dynamime.const_get(format.to_s.upcase)
      if mime_type.is_a? Dynamime::Type and depth < 10
        begin
          find_template_without_dynamime(original_template_path, format, false)
        rescue MissingTemplate => ex
          unless mime_type.supertype.nil?
            debug_message "rescue: find_template"
            find_template(original_template_path, mime_type.supertype.to_sym, false, depth + 1)
          else
            raise ex
          end
        end
      else
        debug_message "rescue: find_template for non-Dynamime::Type"
        find_template_without_dynamime(original_template_path, format, html_fallback)
      end
    end
  end
end
