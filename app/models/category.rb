class Category < ApplicationRecord
  has_many :transactions, dependent: :nullify, class_name: "Transaction"
  has_many :import_mappings, as: :mappable, dependent: :destroy, class_name: "Import::Mapping"

  belongs_to :family

  has_many :budget_categories, dependent: :destroy
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  belongs_to :parent, class_name: "Category", optional: true

  validates :name, :color, :lucide_icon, :family, presence: true
  validates :name, uniqueness: { scope: :family_id }

  validate :category_level_limit
  validate :nested_category_matches_parent_classification

  before_save :inherit_color_from_parent

  scope :alphabetically, -> { order(:name) }
  scope :alphabetically_by_hierarchy, -> {
    left_joins(:parent)
      .order(Arel.sql("COALESCE(parents_categories.name, categories.name)"))
      .order(Arel.sql("parents_categories.name IS NOT NULL"))
      .order(:name)
  }
  scope :roots, -> { where(parent_id: nil) }
  scope :incomes, -> { where(classification: "income") }
  scope :expenses, -> { where(classification: "expense") }

  COLORS = %w[#e99537 #4da568 #6471eb #db5a54 #df4e92 #c44fe9 #eb5429 #61c9ea #805dee #6ad28a]

  UNCATEGORIZED_COLOR = "#737373"
  OTHER_INVESTMENTS_COLOR = "#e99537"
  TRANSFER_COLOR = "#444CE7"
  PAYMENT_COLOR = "#db5a54"
  TRADE_COLOR = "#e99537"

  # Category name keys for i18n
  UNCATEGORIZED_NAME_KEY = "models.category.uncategorized"
  OTHER_INVESTMENTS_NAME_KEY = "models.category.other_investments"
  INVESTMENT_CONTRIBUTIONS_NAME_KEY = "models.category.investment_contributions"
  DEFAULT_CATEGORY_NAME_KEYS = {
    income: "models.category.defaults.income",
    food_and_drink: "models.category.defaults.food_and_drink",
    groceries: "models.category.defaults.groceries",
    shopping: "models.category.defaults.shopping",
    transportation: "models.category.defaults.transportation",
    travel: "models.category.defaults.travel",
    entertainment: "models.category.defaults.entertainment",
    healthcare: "models.category.defaults.healthcare",
    personal_care: "models.category.defaults.personal_care",
    home_improvement: "models.category.defaults.home_improvement",
    mortgage_or_rent: "models.category.defaults.mortgage_or_rent",
    utilities: "models.category.defaults.utilities",
    subscriptions: "models.category.defaults.subscriptions",
    insurance: "models.category.defaults.insurance",
    sports_and_fitness: "models.category.defaults.sports_and_fitness",
    gifts_and_donations: "models.category.defaults.gifts_and_donations",
    taxes: "models.category.defaults.taxes",
    loan_payments: "models.category.defaults.loan_payments",
    services: "models.category.defaults.services",
    fees: "models.category.defaults.fees",
    savings_and_investments: "models.category.defaults.savings_and_investments",
    investment_contributions: INVESTMENT_CONTRIBUTIONS_NAME_KEY
  }.freeze

  class Group
    attr_reader :category, :subcategories

    delegate :name, :color, to: :category

    def self.for(categories)
      categories.select { |category| category.parent_id.nil? }.map do |category|
        new(category, category.subcategories)
      end
    end

    def initialize(category, subcategories = nil)
      @category = category
      @subcategories = subcategories || []
    end
  end

  class << self
    def icon_codes
      %w[
        ambulance apple award baby badge-dollar-sign banknote barcode bar-chart-3 bath
        battery bed-single beer bike bluetooth bone book book-open briefcase building bus
        cake calculator calendar-heart calendar-range camera car cat chart-line
        circle-dollar-sign circle-parking coffee coins compass cookie cooking-pot
        credit-card dices dog drama drill droplet drum dumbbell film flame flower flower-2
        fuel gamepad-2 gem gift glasses globe graduation-cap hammer hand-heart
        hand-helping heart-handshake handshake headphones heart heart-pulse home hotel
        house ice-cream-cone key landmark laptop leaf lightbulb luggage mail map-pin
        martini mic monitor moon music package palette party-popper paw-print pen pencil
        percent phone pie-chart piggy-bank pill pizza plane plug popcorn power printer
        puzzle receipt receipt-text ribbon scale scissors settings shield shield-plus
        shirt shopping-bag shopping-basket shopping-cart smartphone sparkles sprout
        stethoscope store sun tablet-smartphone tag target tent thermometer ticket train
        trees tree-palm trending-up trophy truck tv umbrella undo-2 unplug users utensils
        video wallet wallet-cards waves wifi wine wrench zap
      ]
    end

    def bootstrap!(locale: nil, localize_existing: true)
      I18n.with_locale(locale.presence || bootstrap_locale) do
        default_categories.each do |category_definition|
          translated_names = translated_names_for(category_definition[:name_key], fallback: category_definition[:fallback_name])
          target_name = I18n.t(category_definition[:name_key], default: category_definition[:fallback_name])
          existing_category = find_bootstrap_category(translated_names, category_definition)

          if existing_category
            maybe_localize_existing_category(existing_category, target_name, category_definition) if localize_existing
            next
          end

          create!(
            name: target_name,
            color: category_definition[:color],
            lucide_icon: category_definition[:icon],
            classification: category_definition[:classification]
          )
        end
      end
    end

    def uncategorized
      new(
        name: I18n.t(UNCATEGORIZED_NAME_KEY),
        color: UNCATEGORIZED_COLOR,
        lucide_icon: "circle-dashed"
      )
    end

    def other_investments
      new(
        name: I18n.t(OTHER_INVESTMENTS_NAME_KEY),
        color: OTHER_INVESTMENTS_COLOR,
        lucide_icon: "trending-up"
      )
    end

    # Helper to get the localized name for uncategorized
    def uncategorized_name
      I18n.t(UNCATEGORIZED_NAME_KEY)
    end

    # Helper to get the localized name for other investments
    def other_investments_name
      I18n.t(OTHER_INVESTMENTS_NAME_KEY)
    end

    # Helper to get the localized name for investment contributions
    def investment_contributions_name
      I18n.t(INVESTMENT_CONTRIBUTIONS_NAME_KEY)
    end

    private
      def bootstrap_locale
        if respond_to?(:proxy_association) && proxy_association&.owner&.respond_to?(:locale)
          return proxy_association.owner.locale.presence || I18n.locale
        end

        I18n.locale
      end

      def translated_names_for(name_key, fallback:)
        I18n.available_locales
          .map { |locale| I18n.t(name_key, locale: locale, default: fallback) }
          .uniq
      end

      def find_bootstrap_category(translated_names, category_definition)
        candidates = where(name: translated_names)
        candidates.find { |category| default_category_signature_match?(category, category_definition) } || candidates.first
      end

      def default_category_signature_match?(category, category_definition)
        category.classification == category_definition[:classification] &&
          category.color == category_definition[:color] &&
          category.lucide_icon == category_definition[:icon]
      end

      def maybe_localize_existing_category(category, target_name, category_definition)
        return unless default_category_signature_match?(category, category_definition)
        return if category.name == target_name
        return if where(name: target_name).where.not(id: category.id).exists?

        category.update!(name: target_name)
      end

      def default_categories
        [
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:income],
            fallback_name: "Income",
            color: "#22c55e",
            icon: "circle-dollar-sign",
            classification: "income"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:food_and_drink],
            fallback_name: "Food & Drink",
            color: "#f97316",
            icon: "utensils",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:groceries],
            fallback_name: "Groceries",
            color: "#407706",
            icon: "shopping-bag",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:shopping],
            fallback_name: "Shopping",
            color: "#3b82f6",
            icon: "shopping-cart",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:transportation],
            fallback_name: "Transportation",
            color: "#0ea5e9",
            icon: "bus",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:travel],
            fallback_name: "Travel",
            color: "#2563eb",
            icon: "plane",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:entertainment],
            fallback_name: "Entertainment",
            color: "#a855f7",
            icon: "drama",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:healthcare],
            fallback_name: "Healthcare",
            color: "#4da568",
            icon: "pill",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:personal_care],
            fallback_name: "Personal Care",
            color: "#14b8a6",
            icon: "scissors",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:home_improvement],
            fallback_name: "Home Improvement",
            color: "#d97706",
            icon: "hammer",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:mortgage_or_rent],
            fallback_name: "Mortgage / Rent",
            color: "#b45309",
            icon: "home",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:utilities],
            fallback_name: "Utilities",
            color: "#eab308",
            icon: "lightbulb",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:subscriptions],
            fallback_name: "Subscriptions",
            color: "#6366f1",
            icon: "wifi",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:insurance],
            fallback_name: "Insurance",
            color: "#0284c7",
            icon: "shield",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:sports_and_fitness],
            fallback_name: "Sports & Fitness",
            color: "#10b981",
            icon: "dumbbell",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:gifts_and_donations],
            fallback_name: "Gifts & Donations",
            color: "#61c9ea",
            icon: "hand-helping",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:taxes],
            fallback_name: "Taxes",
            color: "#dc2626",
            icon: "landmark",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:loan_payments],
            fallback_name: "Loan Payments",
            color: "#e11d48",
            icon: "credit-card",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:services],
            fallback_name: "Services",
            color: "#7c3aed",
            icon: "briefcase",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:fees],
            fallback_name: "Fees",
            color: "#6b7280",
            icon: "receipt",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:savings_and_investments],
            fallback_name: "Savings & Investments",
            color: "#059669",
            icon: "piggy-bank",
            classification: "expense"
          },
          {
            name_key: DEFAULT_CATEGORY_NAME_KEYS[:investment_contributions],
            fallback_name: "Investment Contributions",
            color: "#0d9488",
            icon: "trending-up",
            classification: "expense"
          }
        ]
      end
  end

  def inherit_color_from_parent
    if subcategory?
      self.color = parent.color
    end
  end

  def replace_and_destroy!(replacement)
    transaction do
      transactions.update_all category_id: replacement&.id
      destroy!
    end
  end

  def parent?
    subcategories.any?
  end

  def subcategory?
    parent.present?
  end

  def name_with_parent
    subcategory? ? "#{parent.name} > #{name}" : name
  end

  # Predicate: is this the synthetic "Uncategorized" category?
  def uncategorized?
    !persisted? && name == I18n.t(UNCATEGORIZED_NAME_KEY)
  end

  # Predicate: is this the synthetic "Other Investments" category?
  def other_investments?
    !persisted? && name == I18n.t(OTHER_INVESTMENTS_NAME_KEY)
  end

  # Predicate: is this any synthetic (non-persisted) category?
  def synthetic?
    uncategorized? || other_investments?
  end

  private
    def category_level_limit
      if (subcategory? && parent.subcategory?) || (parent? && subcategory?)
        errors.add(:parent, "can't have more than 2 levels of subcategories")
      end
    end

    def nested_category_matches_parent_classification
      if subcategory? && parent.classification != classification
        errors.add(:parent, "must have the same classification as its parent")
      end
    end

    def monetizable_currency
      family.currency
    end
end
