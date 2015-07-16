class GlysellinCart
  defaults =
    onUpdated: null

  constructor: (@container, options) ->
    @options = $.extend({}, defaults, options)
    @add_to_cart_forms = $('[data-add-to-cart-form]')
    @bindAll()

  bindAll: ->
    @add_to_cart_forms.on 'ajax:success', (e, resp) =>
      @update(resp)

  update: (markup) ->
    $markup = $(markup)
    $cart = $markup.find('.cart-container')
    $modal = $markup.find('.added-to-cart-warning').remove()

    @container.html($cart.html())

    if $modal.length > 0
      if @options.handleAddedToCartModal
        @options.handleAddedToCartModal($modal)
      else
        $modal.prependTo('body')
        if ($default_modal = $modal.filter("[data-warning]"))
          @handleDefaultModal($default_modal)

    @updated()

  updated: ->
    # Allow app to update cart handlers when content updated
    @container.trigger('updated.glysellin')
    # Trigger update callback if passed
    @options.onUpdated(this) if $.isFunction(@options.onUpdated)

  # Default modal handling
  handleDefaultModal: ($modal) ->
    $body = $('body')

    closeFromBody = (e) ->
      if $(e.target).closest("[data-warning]").length == 0
        close()

    close = ->
      $modal.fadeOut(200, -> $modal.remove());
      $body.off "click", closeFromBody
      false

    $modal.on "click", "[data-dismiss=warning]", close
    $body.on "click", closeFromBody

$.fn.glysellinCart = (options) ->
  @each ->
    $cart = $(this)
    data = $cart.data('glysellin.cart')
    $cart.data('glysellin.cart', new GlysellinCart($cart, options)) unless data
