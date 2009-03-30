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
        return orig_custom(mime_type, &block) unless mime_type.is_a? Dynamime::Type

        mime_type.subtypes.each {|t| custom(t, &block) }

        # make a responder for the current type:
        unless @responses[mime_type]
          @order << mime_type
          debug_message "Making a responder block for #{mime_type.to_sym} (#{mime_type.to_s})"
          @responses[mime_type] = Proc.new do
            debug_message "In responder: #{mime_type.to_s} (#{mime_type.to_sym})"
            @response.template.template_format = mime_type.to_sym
            @response.content_type             = mime_type.to_s

            # try to call the block or render the template for this action. if it fails, just return false.
            # if we are responding to a subtype of any MIME type, the parent type will hopefully succeed.
            if block_given?
              debug_message "block given #{block.to_s}"
              block.call
            else
              debug_message "rendering #{@controller.action_name}"
              @controller.send(:render, :action => @controller.action_name)
            end
          end
        end
      end

      def respond
        debug_message "MimeResponds::Responder#respond: @mime_type_priority (accepted types): #{@mime_type_priority.inspect}"
        debug_message "MimeResponds::Responder#respond: @order (offered types): #{@order.inspect}"
        for priority in @mime_type_priority
          if priority == Dynamime::ALL
            debug_message "found MIME::ALL => responding with '#{priority.to_sym}'"
            respond_to_all and return
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

      def respond_to_all
        if @order.include? Dynamime::HTML
          @responses[Dynamime::HTML].call
        else
          @responses[@order.first].call
        end
      end
    end
  end
end

