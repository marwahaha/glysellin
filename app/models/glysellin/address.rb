module Glysellin
  class Address < ActiveRecord::Base
    self.table_name = 'glysellin_addresses'

    has_many :billed_orders, :class_name => 'Glysellin::Order', :foreign_key => 'billing_address_id'
    has_many :shipped_orders, :class_name => 'Glysellin::Order', :foreign_key => 'shipping_address_id'

    # Additional fields can be added through Glysellin.config.additional_address_fields in the custom initializer
    store :additional_fields, :accessors => Glysellin.additional_address_fields

    # Give a default address name to manage them or
    # to render a name in admin panels
    def address_name
      "#{ first_name } #{ last_name } - #{ id }"
    end
  end
end
