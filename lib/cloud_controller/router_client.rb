module VCAP::CloudController
  class RouterClient
    class << self
      def setup(config, message_bus)
        @config = config
        @message_bus = message_bus

        @message_bus.subscribe("router.start") do |message|
          setup_registration_interval(message)
        end

        register
        greet_router

        @message_bus.recover do
          register
          greet_router
        end
      end

      def unregister(&callback)
        called = false
        wrapped_callback = proc {
          callback.call unless called || callback.nil?
          called = true
        }

        @message_bus.publish("router.unregister", unregister_message, &wrapped_callback)
        EM.add_timer(message_bus_timeout, &wrapped_callback)
      end

      def message_bus_timeout
        2.0
      end

      private

      def register(interval=nil)
        @message_bus.publish("router.register", register_message)

        if interval
          EM.cancel_timer(@registration_timer) if @registration_timer
          @registration_timer = EM.add_periodic_timer(interval) do
            @message_bus.publish("router.register", register_message)
          end
        end
      end

      def greet_router
        @message_bus.request("router.greet") do |response|
          setup_registration_interval(response)
        end
      end

      def setup_registration_interval(message)
        interval = message.nil? ? nil : message[:minimumRegisterIntervalInSeconds]
        register(interval)
      end

      def register_message
        {
            :host => @config[:bind_address],
            :port => @config[:port],
            :uris => @config[:external_domain],
            :tags => { :component => "CloudController" },
        }
      end

      alias unregister_message register_message
    end
  end
end