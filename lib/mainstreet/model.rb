module MainStreet
  module Model
    def validates_address(fields:, geocode: false, country: nil, accuracy: nil, address_parts: nil, **options)
      fields = Array(fields.map(&:to_s))
      geocode_options = {latitude: :latitude, longitude: :longitude}
      geocode_options = geocode_options.merge(geocode) if geocode.is_a?(Hash)
      options[:if] ||= -> { fields.any? { |f| changes.key?(f.to_s) } } unless options[:unless]

      class_eval do
        validate :verify_address, **options

        define_method :verify_address do
          address = fields.map { |v| send(v).presence }.compact.join(", ")
          address_parts_with_values = {}
          if address_parts.present?
            address_parts_with_values[:address_1] = send(address_parts.first[:address_1])
            address_parts_with_values[:address_2] = send(address_parts.first[:address_2])
            address_parts_with_values[:city] = send(address_parts.first[:city])
            address_parts_with_values[:state] = send(address_parts.first[:state])
            address_parts_with_values[:postcode] = send(address_parts.first[:postcode])
          end
          if address.present?
            # must use a different variable than country
            record_country = instance_exec(&country) if country.respond_to?(:call)
            verifier = MainStreet::AddressVerifier.new(address, country: record_country, accuracy: accuracy, address_parts: address_parts_with_values )
            if verifier.success?
              if geocode
                self.send("#{geocode_options[:latitude]}=", verifier.latitude)
                self.send("#{geocode_options[:longitude]}=", verifier.longitude)
              end

              if address_parts.present?

                if verifier.confirm_city_error_message.present?
                  errors.add(address_parts.first[:city],verifier.confirm_city_error_message )
                end

                if verifier.confirm_state_error_message.present?
                  errors.add(address_parts.first[:state],verifier.confirm_state_error_message )
                end

                if verifier.confirm_postcode_error_message.present?
                  errors.add(address_parts.first[:postcode],verifier.confirm_postcode_error_message )
                end

                if verifier.confirm_street_address_error_message.present?
                  errors.add(address_parts.first[:address_1],verifier.confirm_street_address_error_message )
                end
              end

            else
              errors.add(:address_1, verifier.failure_message)
            end


            # legacy - for standardize_address method
            @address_verification_result = verifier.result
          end
        end
      end
    end
  end
end
