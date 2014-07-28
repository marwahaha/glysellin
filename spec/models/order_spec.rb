require "spec_helper"

describe Glysellin::Order do
  it { should have_many(:payments) }
  it { should have_one(:cart) }
  it { should have_one(:invoice) }

  it { should belong_to(:customer) }
  it { should accept_nested_attributes_for(:payments) }

  it { should validate_presence_of(:customer) }
  it { should validate_presence_of(:billing_address) }
  it { should validate_presence_of(:parcels) }

  before(:each) do
    @order = create(:order)
  end

  context 'before validation' do
    it 'checks prices' do
      expect(@order).to receive(:process_total_price)
      @order.save
    end
  end

  describe "callbacks" do
    context "before validation" do
      it "processes adjustments" do
        expect(@order).to receive(:process_payments)
        @order.save
      end
    end
  end

  describe "#ensure_ref" do
    it "sets the order reference to TIMESTAMP-ORDER_ID by defaut" do
      @order.ensure_ref
      expect(@order.ref.split(/-/).pop).to eq('1')
    end

    it "sets the order reference to TIMESTAMP-ORDER_ID if another :id" do
      @order.ref = '123456'
      @order.ensure_ref
      expect(@order.ref).to eq('123456')
    end

    it "uses Glysellin.order_reference_generator" do
      @order.ensure_ref
      expect(@order.ref).to eq "#{ Time.now.strftime('%Y%m%d%H%M') }-#{ @order.id }"
    end
  end

  describe "#ensure_customer_addresses" do
    [
      [false, false, false, :to, :not_to     ],
      [true, false, false,  :not_to, :not_to ],
      [false, true, false,  :to, :not_to     ],
      [true, true, false,   :not_to, :not_to ],
      [false, false, true,  :to, :to         ],
      [true, false, true,   :not_to, :to     ],
      [false, true, true,   :to, :not_to     ],
      [true, true, true,    :not_to, :not_to ]
    ].each do |(billing_address, shipping_address, use_another_address_for_shipping, comparator_1, comparator_2)|

      it "fills addresses with following arguments: {
        (
          #{billing_address},
          #{shipping_address},
          #{use_another_address_for_shipping},
          #{comparator_1},
          #{comparator_2}
        )
      }" do
        @order.customer.billing_address = billing_address ? create(:address) : nil
        @order.customer.shipping_address = shipping_address ? create(:address) : nil
        @order.customer.use_another_address_for_shipping = use_another_address_for_shipping
        @order.ensure_customer_addresses

        customer_billing_address = @order.customer.billing_address
        customer_shipping_address = @order.customer.shipping_address

        order_billing_address = @order.billing_address
        order_shipping_address = @order.shipping_address

        for attribute in [:first_name, :last_name, :address, :zip, :city, :country]
          unless billing_address
            expect(customer_billing_address.send(attribute)).send(comparator_1, eq(order_billing_address.send(attribute)))

            if use_another_address_for_shipping && !shipping_address
              expect(customer_shipping_address.send(attribute)).send(comparator_2, eq(order_shipping_address.send(attribute)))
            end
          end
        end
      end
    end
  end
end