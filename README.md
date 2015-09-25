# Glysellin

Glysellin is a Rails lightweight e-commerce solution that helps you get simple products, orders and payment gateways without the whole set of functionalities a real e-commerce needs.

In order to stay simple, we choosed for now to keep with some strong dependencies that may not fit to your app.

Also, no admin interface is provided so you can integrate it, but we always use [RailsAdmin](https://github.com/sferik/rails_admin).


## Dependencies

* [Devise](https://github.com/plataformatec/devise)
* [Paperclip](https://github.com/thoughtbot/paperclip)
* [Simple Form](https://github.com/plataformatec/simple_form)


## Disclaimer

Glysellin is under development and can now be used, but documentation is poor, there are no tests and API can change quickly while we don't have tested it within enough projects.


## Installing

To process to glysellin's installation, you shall use the install generator which will :

* Create an initializer file to configure the shop's behavior
* Copy all needed migrations
* Migrate and seed default data
* Mount the engine
* Copy the actions and mailers views to be overriden

The install generator command :

```bash
rails generate glysellin:install
```

## Configuration

To make Glysellin work, your application needs some configuration.
Here are the needed steps :

* Configure javascript plugins integration
* Create a default store for your stocks
* Add the shipping methods you want to make available
* Add the payment methods
* Create a Devise user model and configure it

### Configure javascript plugins integration

There are some javascript plugins that ease glysellin's order integration.

You can add them by creating a specific file (`glysellin.coffee`) and
choosing from those plugins :

```coffeescript
# Require the plugins
#
#= require glysellin/base

# Use on('ready') if you don't use turbolinks or on('page:change') if you use it
$(document).on 'page:change', ->
  # Handles "Add to cart" button and "Added to cart" modal as a Bootstrap modal
  $('.cart-container').glysellinCart
    handleAddedToCartModal: ($modal) -> $modal.modal()

  # Handle the "Choose another address for shipping" form switch
  $('.addresses-fields-container').glysellinAddress()

  # Allows updating the cart recap asynchornously when marked as "Editable"
  $('.products-recap-form.editable').glysellinAsyncCart()
```

### Create a default store for your stocks

Configure the default store for your stocks :

```bash
rails runner "Glysellin::Store.create(name: 'default')"
```

If you need multi-stores handling, that's something possible, but not
implemented to be easily usable for now. Feel free to open an issue to discuss
it.

### Add the shipping methods you want to make available

Glysellin implements some shipping carrier interfaces by default, which can,
for a french setup be enough most of the time. If the interface you need does
not exist, you can create one yourself using the ShippingCarrier API.

Once you know which carrier you want to choose, just create them referencing
the carrier in the `ShippingMethod#identifier` field :

```bash
rails runner "Glysellin::ShippingMethod.create(name: 'Colissimo', identifier: 'colissimo')"
```

#### Existing carrier integrations :

* colissimo : La Poste Colissimo prices grid driven by a CSV file
* lettre_max : La Poste Lettre Max prices grid driven by a CSV file
* fixed_price : Allows to add a shipping method with a fixed price
* free_shipping : Allows creating shipping methods that are free, like actual shop withdrawal.

#### Creating a carrier intragration :

Create a carrier class in `lib/` and require it from an initializer, like the
`glysellin.rb` initializer generated by the install generator.

Please check the existing carriers, and subclass them.

### Add the payment methods

Just like the shipping methods, payment methods work the same and are base on
payment gateways.

Create the ones you need :

```bash
rails runner "Glysellin::PaymentMethod.create(name: 'Credit Card', identifier: 'atos')"
rails runner "Glysellin::PaymentMethod.create(name: 'Credit Card', identifier: 'systempay')"
```

#### Existing gateway integrations :

* paypal_integral : Paypal integral simple integration
* atos : Atos integration for the banks that use it (BNP, Societe Generale, LCL, and more ...)
* cic : CIC / Credit mutuel system integration
* systempay : Banque Populaire / Credit du nord system integration
* check : An integration that displays a message with the direction to send a check to pay the order.

SystemPay needs [youbook's SystemPay gem](https://github.com/youboox/system_pay/). Please include it to 
your app Gemfile

```ruby
gem 'system_pay', github: 'youboox/system_pay'
```

You then need to set up a `config/system_pay.yml` file as described in (the Readme)[https://github.com/youboox/system_pay/#in-configsystem_payyml]

### Create a Devise user model and configure it

Glysellin depends on [Devise](https://github.com/plataformatec/devise) and
needs a user model to attach a customer to.
The customer is the model that holds carts, orders, and customer informations.
The user model is only used for authentication.

Create a user model, and configure its class in the `glysellin.rb` initializer.
The default is `'User'`.

```ruby
# config/initializers/glysellin.rb

module Glysellin
  self.config do |config|
    config.user_class_name = 'User'
  end
end
```

Then add to your user model the relation to the customer :

```ruby
# app/models/user.rb

class User < ActiveRecord::Base
  has_one :customer, class_name: 'Glysellin::Customer'
end
```

## Using the Cart

The shopping cart contents are stored in the Cart model and the cart id in the
user's session. This allows for better code sharing between the cart and the
order, but will leave some artifacts.

The abandonned carts can be used as a metric, to contact back the users, or
be cleaned with a custom rake task. This is up to you and not managed by
Glysellin.

### Displaying the cart

To display the cart you must render it's partial in your layout :

```erb
<%= render_cart %>
```


### Filling the cart

To fill the cart, you can use the pre-built helper to create a simple
"Add to cart" form that asynchronously updates user's cart contents.

You must pass the helper a `Glysellin::Sellable` instance :

```erb
<%= add_to_cart_form(@sellable) %>
```

## Managing orders

By default, being bound to Devise, Glysellin automatically generates anonymous
users to bind orders to. You can choose to keep this behavior alone, or add
real subscription in the ordering process or remove the default behavior to
force users to create an account by switching off the default functionality
in the initializer (default parameter is commented) :

```ruby
# config/initializers/glysellin.rb
Glysellin.config do |config|
  # Allows creating fake accounts for customers with automatic random
  # password generation
  # Defaults to true
  #
  config.allow_anonymous_orders = true
end
```


## Customizing Order behavior

Since the Order object is implemented with the [state_machine gem](), it emits state transition events.
On install, a sample observer is copied to `app/models/order_observer.rb` in your application.
To be able to use it, you must configure your app to allow the `OrderObserver` to listen to `Order` state transitions by uncommenting and editing the following `active_record.observers` config line in your `application.rb` file :

```ruby
# config/application.rb

# Activate observers that should always be running.
config.active_record.observers = :order_observer
```

## Gateway integration

The routes to redirect the payments gateways to are :

* For the automatic Server to Server response : `http://yourapp.com/<glysellin_mount_point>/orders/gateway/:gateway` where :gateway is the gateway slug
* For the "Return to shop" redirections :
    * Success response : `http://yourapp.com/<glysellin_mount_point>/orders/gateway/response/paid`
    * Error response : `http://yourapp.com/<glysellin_mount_point>/orders/gateway/response/cancel`
