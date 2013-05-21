module Glysellin
  class CartController < ApplicationController
    include ActionView::Helpers::NumberHelper

    before_filter :set_cart
    after_filter :update_cart_in_session

    def show
      @cart.update_quantities!
    end

    def destroy
      @cart = Cart.new
      session.delete("glysellin.cart")
      redirect_to cart_path
    end

    protected

    def render_cart_partial
      render partial: 'cart', locals: {
        cart: @cart
      }
    end

    def set_cart
      @cart ||= Cart.new(session["glysellin.cart"])
      @states = @cart.available_states
    end

    # Helper method to set cookie value
    def update_cart_in_session options = {}
      if @cart.errors.any?
        flash[:error] =
          t("glysellin.errors.cart.state_transitions.#{ @cart.state }")
      end

      session["glysellin.cart"] = @cart.serialize
    end

    def totals_hash
      adjustment = @cart.discount

      discount_name = adjustment.name rescue nil
      discount_value = number_to_currency(adjustment.value) rescue nil

      {
        discount_name: discount_name,
        discount_value: discount_value,
        total_eot_price: number_to_currency(@cart.total_eot_price),
        total_price: number_to_currency(@cart.total_price),
        eot_subtotal: number_to_currency(@cart.eot_subtotal),
        subtotal: number_to_currency(@cart.subtotal)
      }
    end
  end
end