module ActionView #:nodoc:
  class TemplateFinder
    include Dynamime
    # for Mime::Type instances, this does exactly the same as the Rails (2.1.2) version.
    # for Dynamime::Type instances, it looks for a template for that type or any of its
    # supertypes, if none is found.
    def find_template_extension_from_handler(template_path, template_format = @template.template_format)
#       debug_message "find_template_extension_from_handler(#{template_path}, #{template_format.inspect})"
      requested_format = Dynamime::Type.lookup_by_extension(template_format.to_s)
      all_types  = [template_format]
      all_types |= requested_format.supertype_symbols if requested_format.is_a? Dynamime::Type
      view_paths.each do |path|
        extension = all_types.find do |mime_type|
          if ext = @@file_extension_cache[path]["#{template_path}.#{mime_type}"].first
            return "#{mime_type}.#{ext}"
          end
        end

        extensions = @@file_extension_cache[path][template_path]
        return extensions.first.to_s if extensions.any?
      end
      nil
    end

    def find_base_path_for(template_file_name)
      @view_paths.find { |path| @@processed_view_paths[path].include?("#{template_file_name}") }
    end
  end
end

module ActionController #:nodoc:
  module Layout #:nodoc:
    module ClassMethods
      include Dynamime

      private

      # for Mime::Type instances of +req_format+, this does exactly the same as the Rails (2.1.2) version.
      # for Dynamime::Type instances, it also looks for layouts associated with any ot +req_format+'s
      # supertypes, if no layout for +req_format+ is given.
      def default_layout_with_format(req_format, layout)
        extension   = req_format.to_s
        list        = layout_list
        format_list = [req_format]
        format_type = Dynamime::Type.lookup_by_extension(extension)
        format_list |= format_type.supertype_symbols if format_type.is_a? Dynamime::Type
        debug_message "format_list: #{format_type.inspect}"
        found_format = format_list.find {|fmt| !list.grep(%r{layouts/#{layout}\.#{fmt}(\.[a-z][0-9a-z]*)+$}).empty? }
        if found_format.nil?
          (!list.grep(%r{layouts/#{layout}\.([a-z][0-9a-z]*)+$}).empty? and extension == 'html') ? layout : nil
        else
          layout
        end
      end
    end
  end
end