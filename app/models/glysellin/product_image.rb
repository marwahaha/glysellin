module Glysellin
  class ProductImage < ActiveRecord::Base
    self.table_name = 'glysellin_product_images'

    belongs_to :imageable, :polymorphic => true

    has_attached_file :image, :styles => Glysellin.product_images_styles
  end
end
