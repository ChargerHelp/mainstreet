require "bundler/setup"
require "active_record"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "vcr"
require "webmock"
require 'byebug'

def smarty_streets?
  !ENV["SMARTY_STREETS_AUTH_ID"].nil?
end

I18n.load_path << Dir[File.expand_path("locales", __dir__) + "/*.yml"]

VCR.configure do |c|
  c.hook_into :webmock
  c.cassette_library_dir = "test/cassettes"
  c.filter_sensitive_data("<auth-id>") { ENV["SMARTY_STREETS_AUTH_ID"] } if ENV["SMARTY_STREETS_AUTH_ID"]
  c.filter_sensitive_data("<auth-token>") { ENV["SMARTY_STREETS_AUTH_TOKEN"] } if ENV["SMARTY_STREETS_AUTH_TOKEN"]
  c.filter_sensitive_data("<api-key>") { ENV["GEOCODIO_API_KEY"] } if ENV["GEOCODIO_API_KEY"]
end

cassette_name = smarty_streets? ? "smarty_streets" : "default"
VCR.insert_cassette(cassette_name, record: :once)
Minitest.after_run { VCR.eject_cassette }

ActiveRecord::Base.logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)
ActiveRecord::Migration.verbose = ENV["VERBOSE"]

# migrations
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :addresses do |t|
  t.text :street
  t.text :city
  t.string :region
  t.string :postal_code
  t.string :country
  t.decimal :latitude
  t.decimal :longitude
end

class Address < ActiveRecord::Base
  validates_address fields: [:street, :city, :region, :postal_code],
                    geocode: true,
                    country: -> { country }
end


ActiveRecord::Migration.create_table :address_with_accuracies do |t|
  t.text :street
  t.text :apt
  t.text :city
  t.string :region
  t.string :postal_code
  t.string :country
  t.decimal :latitude
  t.decimal :longitude
end

class AddressWithAccuracy < ActiveRecord::Base
  validates_address fields: [:street, :city, :region, :postal_code],
                    address_parts: [address_1: :street, address_2: :apt, city: :city, state: :region, postcode: :postal_code],
                    geocode: true,
                    accuracy: 1,
                    country: -> { country }
end

def use_geocodio
  if ENV["GEOCODIO_API_KEY"]
    Geocoder.configure(
      lookup: :geocodio,
      geocodio: {
        api_key: ENV["GEOCODIO_API_KEY"]
      })
  end
end

def use_nominatim
  if ENV["GEOCODIO_API_KEY"]
    Geocoder.configure(
      lookup: :nominatim)
  end
end