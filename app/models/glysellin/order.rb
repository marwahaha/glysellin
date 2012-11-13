module Glysellin
  class Order < ActiveRecord::Base
    self.table_name = 'glysellin_orders'

    # Relations
    #
    # Order items are used to map order to cloned and simplified products
    #   so the Order propererties can't be affected by product updates
    has_many :items, :class_name => 'Glysellin::OrderItem', :foreign_key => 'order_id'
    # The actual buyer
    belongs_to :customer, :class_name => "::#{ Glysellin.user_class_name }", :inverse_of => :orders
    # Addresses
    belongs_to :billing_address, :foreign_key => 'billing_address_id', :class_name => 'Glysellin::Address', :inverse_of => :billed_orders
    belongs_to :shipping_address, :foreign_key => 'shipping_address_id', :class_name => 'Glysellin::Address', :inverse_of => :shipped_orders
    # Payment tries
    has_many :payments, :inverse_of => :order

    # We want to be able to see fields_for addresses
    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :shipping_address
    accepts_nested_attributes_for :items
    accepts_nested_attributes_for :customer
    accepts_nested_attributes_for :payments

    attr_accessible :billing_address_attributes, :shipping_address_attributes,
      :billing_address, :shipping_address, :payments,
      :items, :items_ids, :customer, :customer_id, :ref, :status, :paid_on,
      :user, :items, :payments, :customer_attributes, :payments_attributes,
      :items_attributes

    # Status const to be used to define order step to cart shopping
    ORDER_STEP_CART = 'cart'
    # Status const to be used to define order step to address
    ORDER_STEP_ADDRESS = 'fill_addresses'
    # Status const to be used to define order step to defining payment method
    ORDER_STEP_PAYMENT_METHOD = 'recap'
    # Status const to be used to define order step to payment
    ORDER_STEP_PAYMENT = 'payment'

    # Status const to be used to define order status to payment
    ORDER_STATUS_PAYMENT_PENDING = 'payment'
    # Status const to be used to define order status to paid
    ORDER_STATUS_PAID = 'paid'
    # Status const to be used to define order status to shipping
    ORDER_STATUS_SHIPPING_PENDING = 'shipping'
    # Status const to be used to define order status to shipped
    ORDER_STATUS_SHIPPED = 'shipped'

    # Ensure there is always an order reference for billing purposes
    after_save do
      unless self.ref
        self.ref = self.generate_ref
        self.save
      end
    end

    def status_enum
      [ORDER_STATUS_PAYMENT_PENDING, ORDER_STATUS_PAID, ORDER_STATUS_SHIPPING_PENDING, ORDER_STATUS_SHIPPED].map do |s|
        [I18n.t("glysellin.labels.orders.statuses.#{ s }"), s]
      end
    end

    # Define model to use it's ref when asked for parameterized
    #   representation of itself
    #
    # @return [String] the order ref
    def to_param
      ref
    end

    # Automatic ref generation for an order that can be overriden
    #   within the config initializer, and only executes if there's no
    #   existing ref inside for this order
    #
    # @return [String] the generated or existing ref
    def generate_ref
      if ref
        ref
      else
        if Glysellin.order_reference_generator
          Glysellin.order_reference_generator.call(self)
        else
          "#{Time.now.strftime('%Y%m%d%H%M')}-#{id}"
        end
      end
    end

    # Used to parse an Order item serialized into JSON
    #
    # @param [String] json JSON string object representing the order attributes
    #
    # @return [Boolean] wether or not the object has been
    #   successfully initialized
    def initialize_from_json! json
      self.attributes = ActiveSupport::JSON.decode(json)
    end

    # Gives the next step to ask user to pass through
    #   given the state of the current order deined by the informations
    #   already filled in the model
    def next_step
      if items.length == 0
        ORDER_STEP_CART
      elsif !billing_address
        ORDER_STEP_ADDRESS
      elsif !(payments.length > 0)
        ORDER_STEP_PAYMENT_METHOD
      elsif payments.last.status == Payment::PAYMENT_STATUS_PENDING
        ORDER_STEP_PAYMENT
      end
    end

    # Deprecated: sucks because we can Order.find_by_ref(ref)
    def self.from_ref ref
      where(:ref => ref).first
    end

    # Gets order subtotal from items only
    #
    # @param [Boolean] df Defines if we want to get duty free price or not
    #
    # @return [BigDecimal] the calculated subtotal
    def subtotal df = false
      @_subtotal ||= items.reduce(0) {|l, r| l + (df ? r.eot_price : r.price)}
    end

    # Not implemented yet
    def shipping_price df = false
      0
    end

    # Gets order total price from subtotal and adjustments
    #
    # @param [Boolean] df Defines if we want to get duty free price or not
    #
    # @return [BigDecimal] the calculated total price
    def total_price df = false
      @_total_price ||= (subtotal(df) + shipping_price(df))
    end

    # Customer's e-mail directly accessible from the order
    #
    # @return [String] the wanted e-mail string
    def email
      customer.email
    end

    ########################################
    #
    #               Payment
    #
    ########################################

    # Gives the last payment found for that order
    #
    # @return [Payment, nil] the found Payment item or nil
    def payment
      payments.last
    end

    # Returns the last payment method used if there has already been
    #   a payment try
    #
    # @return [PaymentType, nil] the PaymentMethod or nil
    def payment_method
      payment.type rescue nil
    end

    # Tells the order it is paid and processes to the necessary
    #   updates the model and related object need to retrieve payment infos
    #
    # @return [Boolean] if the doc was saved
    def pay!
      self.payment.new_status Payment::PAYMENT_STATUS_PAID
      self.status = ORDER_STATUS_PAID
      self.paid_on = payment.last_payment_action_on
      self.save
    end

    # Tells if the order is currently paid or not
    #
    # @return [Boolean] whether it is paid or not
    def paid?
      payment.status == Payment::PAYMENT_STATUS_PAID
    end
  end


  class << self
    # Permits to create or update an order from nested forms (hashes)
    #   and can create a whole order object ready to be paid but
    #   only modifies the order from the params passed in the order_hash param
    #
    # @param [Hash] order_hash Hash of hashes containing order data from nested forms
    # @param [Customer] customer Customer object to map to the order
    #
    # @example Setting shipping address
    #   Glysellin::Order.from_sub_forms { shipping_address: { first_name: 'Me' ... } }
    #
    # @return [] the created or updated Order item
    def from_sub_forms order_hash, customer = nil
      # Fetch order from order_hash id if given
      if (id = order_hash[:order_id])
        order = Order.find(id)
      # Or create a new one
      else
        order = Order.new
      end

      # Try to fill as much as we can
      order.fill_addresses_from_hash(order_hash)
      order.fill_payment_method_from_hash(order_hash)
      order.fill_products_from_hash(order_hash)
      order.fill_product_choices_from_hash(order_hash)

      #
      order
    end
  end

  def fill_addresses_from_hash order_hash
    return unless order_hash[:billing_address]
    # Store billing address
    self.billing_address = Address.new order_hash[:billing_address]

    # Check if we have to use the billing address for shipping
    if order_hash[:billing_address][:use_billing_address_for_shipping]
      same_address = order_hash[:billing_address][:use_billing_address_for_shipping].presence
    else
      same_address = false
    end

    # Define shipping address if we must use same address
    if same_address
      self.shipping_address = Address.new order_hash[:billing_address]
    # Else, if we are given a specific shipping address
    elsif order_hash[:shipping_address]
      self.shipping_address = Address.new order_hash[:shipping_address]
    end
  end

  def fill_payment_method_from_hash order_hash
    return unless order_hash[:payment_method] && order_hash[:payment_method][:type]

    payment = self.payments.build :status => Payment::PAYMENT_STATUS_PENDING
    payment.type = PaymentMethod.find_by_slug(order_hash[:payment_method][:type])
    self.status = ORDER_STATUS_PAYMENT_PENDING
  end

  def fill_products_from_hash order_hash
    return unless order_hash[:products] && order_hash[:products].length > 0

    order_hash[:products].each do |product_slug, value|
      if product_slug && value != '0'
        item = OrderItem.create_from_product_slug(product_slug)
        self.items << item if item
      end
    end
  end

  def fill_product_choices_from_hash order_hash
    return unless order_hash[:product_choice] && order_hash[:product_choice].length > 0

    order_hash[:product_choice].each_value do |product_slug|
      if product_slug
        item = OrderItem.create_from_product_slug(product_slug)
        self.items << item if item
      end
    end
  end

end
