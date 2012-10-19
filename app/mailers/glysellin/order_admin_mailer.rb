class Glysellin::OrderAdminMailer < ActionMailer::Base
  default from: Glysellin.contact_email

  def send_order_paid_email order
    @order = order
    mail to: Glysellin.admin_email
  end

  def send_new_check_order_email order
    @order = order
    mail to: Glysellin.admin_email
  end
end
