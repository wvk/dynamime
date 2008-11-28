def debug_message(*args)
  args[0] = "Dynamime: #{args[0]}"
  RAILS_DEFAULT_LOGGER.debug args if defined? DEBUG_DYNAMIME and DEBUG_DYNAMIME
end

module Dynamime
  include Mime
  DEVICES = {}

  class Type < Mime::Type

    def const_missing(konst_name) # :nodoc:
      konst = Mime.send :const_get, konst_name
      self.const_set konst_name, konst
    end

    def subtype_of?(other_type)
      other_type = Type.lookup_by_extension "#{other_type}" unless other_type.is_a? self.class
      supertypes.include? other_type
    end

    # get direct ascendants of current type
    def subtypes
      syms = Dynamime::DEVICES.keys.reject {|key| Dynamime::DEVICES[key] != self.to_sym }
      syms.collect {|sym| self.class.lookup_by_extension "#{sym}" }
    end

    # the "supertype" of a MIME type can be seen as a fallback if
    # e.g. the requested mime type is not available for processing
    def supertype
      Dynamime::DEVICES[self.to_sym] ? self.class.lookup_by_extension("#{Dynamime::DEVICES[self.to_sym]}") : nil
    end

    # get all parent/fallback types of current type, in ascending order
    def supertypes
      st = self.supertype
      st ? ([st] | (st.respond_to?(:supertypes) ? st.supertypes : [])) : []
    end

    # get all parent/fallback types of current type, in ascending order, as symbols
    def supertype_symbols
      st = self.supertype
      st ? ([st.to_sym] | (st.respond_to?(:supertype_symbols) ? st.supertype_symbols : [])) : []
    end

    # the "master fallback".
    def toplevel_supertype
      if (st = self.supertype).nil?
        self
      elsif st.respond_to? :toplevel_supertype
        st.toplevel_supertype
      else
        st
      end
    end

    class << self
      # add new mime types for mobile devices:
      # the second parameter indicates that a type is a "subtype" of another one.
      # This way you can create mime types for specific devices, browser versions
      # or firmware patchlevels. If no view template for a specific type is found,
      # a more general view template is chosen.
      def register(symbol, parent_type=:html, string=nil, extension_synonyms = [])
        symbol    = symbol.to_sym
        extension = symbol.to_s
        konstant  = symbol.to_s.upcase
        string  ||= (Dynamime::EXTENSION_LOOKUP[parent_type.to_s] || 'application/xhtml+xml').to_s

        index = self.wipe_type(symbol) if Dynamime::EXTENSION_LOOKUP[extension]
        Dynamime::DEVICES[symbol.to_sym] = parent_type.to_sym if parent_type
        Mime.instance_eval { const_set konstant, Dynamime::Type.new(string, symbol) }
        m = Mime.const_get konstant
        if index
          Mime::SET[index] = m
        else
          Mime::SET << m
        end
        debug_message "registering type #{m}"
        Mime::LOOKUP[string] = m
        ([symbol.to_s] + extension_synonyms).each { |ext| Mime::EXTENSION_LOOKUP[ext] = m }
      end

      def unregister(*symbols)
        # TODO: what happens to children of a registered type?
        if symbols.first == :all
          symbols = Dynamime::DEVICES.keys
        end
        symbols.each do |symbol|
          wipe_type(symbol)
        end
        Mime::SET.compact!
      end

      def wipe_type(symbol) # :nodoc:
        type = Mime::LOOKUP[symbol]
        Dynamime::DEVICES.delete symbol
        Mime::LOOKUP.delete symbol
        Mime::EXTENSION_LOOKUP.delete symbol.to_s
        if index = Mime::SET.index(type)
          Mime::SET[index] = nil
        end
        konst = symbol.to_s.upcase
        Mime.instance_eval { self.send(:remove_const, konst) if self.const_defined? konst }
        index
      end
    end

    def self.exists?(name)
      case "#{name}"
        when 'html' then return true
        when ''     then return false
        else return !!Dynamime::DEVICES[name.to_sym]
      end
    end
  end

  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
  end

  module ClassMethods

    def dynamimize
      include Dynamime::InstanceMethods
      before_filter :set_format
      helper_method :in_view?,
                    :client_user_agent,
                    :current_user_agent,
                    :current_user_agent_string
    end
    alias use_device_dependent_views dynamimize
  end

  module InstanceMethods
    # returns true if +symbol+ denotes the currently used view type.
    # Example:
    #    in_view?(:mobile)
    # -> TRUE if mobile view was requested (either, implicitely via
    # UA recognition or explicitely using *.:format in your URI)
    # alternatively, you can use in_mobile_view?, in_html_view? etc.
    def in_view?(symbol)
      params_format = params_format? ? params[:format].to_sym : nil
      [request.format.to_sym, params_format].include? symbol.to_sym
    end

    # sets the output format according to the user agent and the requested mime type.
    # If a client explicitely requests .format, this format is used. Otherwise,
    # the requested format is determined by the requesting platform's UA string
    def set_format
      debug_message "request.format is #{request.format.to_sym} (#{request.format.to_s})." unless request.format.nil?
      if request.format and request.format.html? or client_user_agent.html? or client_user_agent.msie?
        unless params_format?
          mime_type       = client_user_agent
          params[:format] = mime_type.to_sym
          request.format  = mime_type.to_sym
          request.path_parameters = request.path_parameters.merge(:format => params[:format].to_s)
        else
          mime_type = Dynamime::Type.lookup_by_extension params[:format]
        end
      end

      begin
        debug_message "using '#{mime_type.to_sym}' (#{mime_type.to_s}) for rendering."
      rescue
        debug_message "requested MIME type '#{request.format}' was not found!"
      end
    end

    # returns the Dynamime::Type for the current user agent or Dynamime::HTML if no known UA was found.
    def client_user_agent
      current_user_agent
      debug_message "detected User Agent '#{@current_user_agent.full_name}' (#{@current_user_agent.view_platform}) for UA '#{current_user_agent_string}'"
      @current_user_agent.view_mime_type
    end

    # user agent string as sent by the client
    def current_user_agent_string
      request.env['HTTP_USER_AGENT'] || request.user_agent
    end

    # finds a +UserAgent+ suitable for the client's User-Agent header.
    # This is done by a database lookup: the +UserAgent+ with the longest
    # matching detection substring is used. If none is found, a generic
    # +UserAgent+ with default values is returned.
    def current_user_agent
      # makes only sense if an actual request has been made.
      unless request.nil?
        @@generic_user_agent = UserAgent.new(:browser           => Browser.find_or_create_by_name(:name => 'Generic Browser'),
                                               :hardware_platform => HardwarePlatform.find_or_create_by_name(:name => 'Generic Hardware'),
                                               :view_mime_type    => Dynamime::HTML)

        @current_user_agent ||= UserAgent.find(:first,
                                               :conditions => "'#{current_user_agent_string}' LIKE CONCAT('%', `substring`, '%')",
                                               :order      => 'LENGTH(`substring`) DESC') || @@generic_user_agent
      end
    end

    def current_user_agent=(ua)
      debug_message "current_user_agent=(#{ua.inspect})"
      @current_user_agent = ua
    end

    alias orig_method_missing method_missing # :nodoc:

    def method_missing(method_name, *args)
      case method_name.to_s
      when /in_(.*)_view?/
        in_view?($1)
      else
        orig_method_missing method_name, args
      end
    end

    def params_format?
      params[:format] and not params[:format].empty?
    end
  end
end

module ActionController # :nodoc:
  module MimeResponds # :nodoc:
    class Responder
      include Dynamime
      alias orig_custom custom

      # for normal mime types, just call the original custom method. For dynamimed types,
      # also build responder blocks for subtypes of that devices, so e.g. the following code
      # would include a responder to all kinds of mobile devices and normal browsers:
      #    respond_to do |format|
      #      format.mobile
      #      format.html
      #    end
      # however, this example only creates a responder for Nokia devices, iPhones and normal browsers:
      #    respond_to do |format|
      #      format.nokia
      #      format.iphone
      #      format.html
      #    end
      #
      def custom(mime_type, &block)
#         debug_message "called custom(#{mime_type.inspect})"
#         mime_type = Dynamime::Type.lookup_by_extension(mime_type.to_sym)
        unless mime_type.is_a? Dynamime::Type
#           debug_message "NOT a Dynamime::Type: #{mime_type.inspect} -- using original `custom` method."
          return orig_custom(mime_type, &block)
        end
        sub_types = mime_type.subtypes
        # first, make responder blocks for the subtypes...
        if sub_types.any?
          sub_types.each {|t| custom(t, &block) }
        end
        # ...then, make a responder for the current type:
        unless @responses[mime_type]
          @order << mime_type
#           debug_message "Making a responder block for #{mime_type.to_sym} (#{mime_type.to_s})"
          @responses[mime_type] = Proc.new do
            debug_message "In responder: #{mime_type.to_s} (#{mime_type.to_sym})"
            @response.template.template_format = mime_type.to_sym
            @response.content_type             = mime_type.to_s
            # try to call the block or render the template for this action. if it fails, just return false.
            # if we are responding to a subtype of any MIME type, the parent type will hopefully proceed.
            block_given? ? block.call : @controller.send(:render, :action => @controller.action_name)
            debug_message "block given #{block.to_s}" if block_given?
            debug_message "rendering #{@controller.action_name}" unless block_given?
          end
        end
      end

      def respond
        debug_message "MimeResponds::Responder#respond: @mime_type_priority (accepted types): #{@mime_type_priority.inspect}"
        debug_message "MimeResponds::Responder#respond: @order (offered types): #{@order.inspect}"
        for priority in @mime_type_priority
          if priority == Dynamime::ALL
            debug_message "found MIME::ALL => responding with '#{priority.to_sym}'"
            if @order.include? Dynamime::HTML
              @responses[Dynamime::HTML].call
            else
              @responses[@order.first].call
            end
            return
          elsif @responses[priority]
            # Since hierarchical MIME types are registered in most specific -> least specific order,
            # a failure of a more specific responder does not neccessarily mean a general error.
            # in that case, we try other responders until either a responder for a parent type
            # succeeds or we just run out of responders.
            begin
              debug_message "Responding to block for #{priority.to_sym} (#{priority.to_s})"
              @responses[priority].call
              return # mime type match found, be happy and return
            rescue ActionView::MissingTemplate
              debug_message "ActionView::MissingTemplate while responding to #{priority.to_sym} (#{priority.to_s})"
            end
          end
        end

        if @order.include?(Dynamime::ALL)
          debug_message "found no suitable responder, using #{Dynamime::ALL.to_sym} (#{Dynamime::ALL.to_s})"
          @responses[Dynamime::ALL].call
        else
          @controller.send :head, :not_acceptable
        end
      end
    end
  end
end

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

ActionController::Base.send :include, Dynamime

