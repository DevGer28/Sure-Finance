require "test_helper"

class AccountOrderTest < ActiveSupport::TestCase
  test "labels are localized in spanish" do
    I18n.with_locale(:es) do
      order = AccountOrder.new("balance_desc")
      assert_equal "Saldo (de mayor a menor)", order.label
      assert_equal "Saldo ↓", order.label_short
    end
  end
end
