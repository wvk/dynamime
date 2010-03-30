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

      # completely removes a Dynamime::Type so it can e.g. be re-registered with other values
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
    # You can overwrite this method in your Controller in order to implement your own
    # format determination logic.
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
                                               :conditions => "substring LIKE '%#{current_user_agent_string}%'",
                                               :order      => 'LENGTH(substring) DESC') || @@generic_user_agent
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


ActionController::Base.send :include, Dynamime
