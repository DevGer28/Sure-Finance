require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
  end

  test "replacing and destroying" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(categories(:income))

    assert_equal categories(:income), transactions.map { |t| t.reload.category }.uniq.first
  end

  test "replacing with nil should nullify the category" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(nil)

    assert_nil transactions.map { |t| t.reload.category }.uniq.first
  end

  test "subcategory can only be one level deep" do
    category = categories(:subcategory)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      category.subcategories.create!(name: "Invalid category", family: @family)
    end

    assert_equal "Validation failed: Parent can't have more than 2 levels of subcategories", error.message
  end

  test "bootstrap uses family locale for default category names" do
    spanish_family = Family.create!(name: "Familia ES", locale: "es")

    spanish_family.categories.bootstrap!

    assert_equal 22, spanish_family.categories.count
    assert spanish_family.categories.exists?(name: "Ingresos")
    assert spanish_family.categories.exists?(name: "Comida y bebida")
  end

  test "bootstrap does not duplicate categories when family locale changes" do
    family = Family.create!(name: "Locale Switch Family", locale: "en")

    family.categories.bootstrap!
    assert_equal 22, family.categories.count
    assert family.categories.exists?(name: "Income")

    family.update!(locale: "es")
    family.categories.bootstrap!

    assert_equal 22, family.categories.count
    assert family.categories.exists?(name: "Ingresos")
    assert_not family.categories.exists?(name: "Income")
  end
end
