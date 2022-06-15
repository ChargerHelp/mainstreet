module MainStreet
  class AddressVerifier

    attr_accessor :google_address_components

    def initialize(address, country: nil, locale: nil, accuracy: nil, address_parts: nil)
      @address = address
      @country = country
      @locale = locale
      @accuracy = accuracy
      @address_parts = address_parts
    end

    def success?
      failure_message.nil?
    end

    def failure_message
      if !result
        message :unconfirmed, "can't be confirmed"
      elsif result.respond_to?(:analysis)
        analysis = result.analysis

        if analysis["verification_status"]
          case analysis["verification_status"]
          when "Verified"
            nil # success!!
          when "Ambiguous", "Partial", "None"
            message :unconfirmed, "Address can't be confirmed"
          else
            raise "Unknown verification_status"
          end
        elsif analysis["dpv_match_code"]
          case analysis["dpv_match_code"]
          when "Y"
            nil # success!!
          when "N"
            message :unconfirmed, "Address can't be confirmed"
          when "S"
            message :apt_unconfirmed, "Apartment or suite can't be confirmed"
          when "D"
            message :apt_missing, "Apartment or suite is missing"
          else
            raise "Unknown dpv_match_code"
          end
        end
      elsif result.respond_to?(:accuracy) && @accuracy.present?
        if result.accuracy < @accuracy
          if !confirmed_with_google
             message :unconfirmed, "can't be confirmed"
          end
        end
      end
    end

    def confirmed_with_google
      google_results = Geocoder.search(@address, lookup: :google).first
      return false if google_results.nil? || google_results.data.nil? || google_results.data["partial_match"].present? && google_results.data["partial_match"]

      if google_results.data["place_id"].present?
        self.google_address_components = google_results.data["address_components"].to_h {|h| [h["types"][0],h["short_name"]] }
        return true
      else
        return false
      end
    end

    def result
      return @result if defined?(@result)

      @result = begin
                  options = {lookup: MainStreet.lookup}
                  options[:country] = @country if @country && !usa?
                  # don't use smarty streets zipcode only API
                  # keep mirrored with geocoder gem, including \Z
                  # \Z is the same as \z when strip is used
                  if @address.to_s.strip !~ /\A\d{5}(-\d{4})?\Z/
                    Geocoder.search(@address, options).first
                  end
                end
    end

    def latitude
        result && result.latitude
    end

    def longitude
        result && result.longitude
    end

    def confirm_postcode_error_message
      return if google_address_components.present?
        if @address_parts.present? && result.data["address_components"] && result.data["address_components"]["zip"] && result.data["address_components"]["zip"].downcase != @address_parts[:postcode]&.downcase&.strip
          "could not be confirmed, suggested zipcode: #{result.data["address_components"]["zip"]}"
        end
    end

    def confirm_city_error_message
      return if google_address_components.present?
      if @address_parts.present? && result.data["address_components"] && result.data["address_components"]["city"] && result.data["address_components"]["city"].downcase != @address_parts[:city].downcase.strip
        "could not be confirmed, suggested city: #{result.data["address_components"]["city"]}"
      end
    end

    def confirm_state_error_message
      return if google_address_components.present?
      if @address_parts.present? && result.data["address_components"] && result.data["address_components"]["state"] && result.data["address_components"]["state"].downcase != @address_parts[:state].downcase.strip
        "could not be confirmed, suggested state: #{result.data["address_components"]["state"]}"
      end
    end

    def confirm_street_address_error_message
      return if google_address_components.present?
      if @address_parts.present?
        if result.data["address_components"].nil? || result.data["address_components"]["number"].nil? ||  result.data["address_components"]["street"].nil?
          "could not be confirmed, missing street number or name"
        end
      end
    end

    private

    def usa?
      ["United States", "USA", "US", "840"].include?(@country.to_s)
    end

    def message(key, default)
      if defined?(I18n)
        I18n.t(key, scope: [:mainstreet, :errors, :messages], locale: @locale, default: default)
      else
        default
      end
    end
  end
end
