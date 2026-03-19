class Rule::ConditionFilter
  UnsupportedOperatorError = Class.new(StandardError)

  TYPES = [ "text", "number", "select" ]

  OPERATORS_MAP = {
    "text" => [ [ :contains, "like" ], [ :equal_to, "=" ], [ :is_empty, "is_null" ] ],
    "number" => [ [ :greater_than, ">" ], [ :greater_or_equal_to, ">=" ], [ :less_than, "<" ], [ :less_than_or_equal_to, "<=" ], [ :is_equal_to, "=" ] ],
    "select" => [ [ :equal_to, "=" ], [ :is_empty, "is_null" ] ]
  }

  def initialize(rule)
    @rule = rule
  end

  def type
    "text"
  end

  def number_step
    family_currency = Money::Currency.new(family.currency)
    family_currency.step
  end

  def key
    self.class.name.demodulize.underscore
  end

  def label
    I18n.t("rules.condition_filters.labels.#{key}", default: key.humanize)
  end

  def options
    nil
  end

  def operators
    OPERATORS_MAP.fetch(type).map do |operator_key, operator_value|
      [ I18n.t("rules.condition_filters.operators.#{operator_key}", default: operator_key.to_s.humanize), operator_value ]
    end
  end

  # Matchers can prepare the scope with joins by implementing this method
  def prepare(scope)
    scope
  end

  # Applies the condition to the scope
  def apply(scope, operator, value)
    raise NotImplementedError, "Condition #{self.class.name} must implement #apply"
  end

  def as_json
    {
      type: type,
      key: key,
      label: label,
      operators: operators,
      options: options,
      number_step: number_step
    }
  end

  private
    attr_reader :rule

    def family
      rule.family
    end

    def build_sanitized_where_condition(field, operator, value)
      if operator == "is_null"
        ActiveRecord::Base.sanitize_sql_for_conditions(
          "#{field} #{sanitize_operator(operator)}"
        )
      else
        sanitized_value = operator == "like" ? "%#{ActiveRecord::Base.sanitize_sql_like(value)}%" : value

        ActiveRecord::Base.sanitize_sql_for_conditions([
          "#{field} #{sanitize_operator(operator)} ?",
          sanitized_value
        ])
      end
    end

    def sanitize_operator(operator)
      raise UnsupportedOperatorError, "Unsupported operator: #{operator} for type: #{type}" unless operators.map(&:last).include?(operator)

      case operator
      when "like"
        "ILIKE"
      when "is_null"
        "IS NULL"
      else
        operator
      end
    end
end
