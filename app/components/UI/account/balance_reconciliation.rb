class UI::Account::BalanceReconciliation < ApplicationComponent
  attr_reader :balance, :account

  def initialize(balance:, account:)
    @balance = balance
    @account = account
  end

  def reconciliation_items
    case account.accountable_type
    when "Depository", "OtherAsset", "OtherLiability"
      default_items
    when "CreditCard"
      credit_card_items
    when "Investment"
      investment_items
    when "Loan"
      loan_items
    when "Property", "Vehicle"
      asset_items
    when "Crypto"
      crypto_items
    else
      default_items
    end
  end

  private

    def default_items
      items = [
        build_item(label_key: :start_balance, value: balance.start_balance_money, tooltip_key: :account_balance_start_day, style: :start),
        build_item(label_key: :net_cash_flow, value: net_cash_flow, tooltip_key: :account_net_cash_flow, style: :flow)
      ]

      if has_adjustments?
        items << build_item(label_key: :end_balance, value: end_balance_before_adjustments, tooltip_key: :account_end_balance_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: total_adjustments, tooltip_key: :manual_adjustments, style: :adjustment)
      end

      items << build_item(label_key: :final_balance, value: balance.end_balance_money, tooltip_key: :account_final_balance_day, style: :final)
      items
    end

    def credit_card_items
      items = [
        build_item(label_key: :start_balance, value: balance.start_balance_money, tooltip_key: :credit_card_balance_owed_start_day, style: :start),
        build_item(label_key: :charges, value: balance.cash_outflows_money, tooltip_key: :credit_card_new_charges_day, style: :flow),
        build_item(label_key: :payments, value: balance.cash_inflows_money * -1, tooltip_key: :credit_card_payments_day, style: :flow)
      ]

      if has_adjustments?
        items << build_item(label_key: :end_balance, value: end_balance_before_adjustments, tooltip_key: :account_end_balance_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: total_adjustments, tooltip_key: :manual_adjustments, style: :adjustment)
      end

      items << build_item(label_key: :final_balance, value: balance.end_balance_money, tooltip_key: :credit_card_final_balance_owed_day, style: :final)
      items
    end

    def investment_items
      items = [
        build_item(label_key: :start_balance, value: balance.start_balance_money, tooltip_key: :investment_portfolio_value_start_day, style: :start)
      ]

      # Change in brokerage cash (includes deposits, withdrawals, and cash from trades)
      items << build_item(label_key: :change_in_brokerage_cash, value: net_cash_flow, tooltip_key: :investment_change_in_brokerage_cash, style: :flow)

      # Change in holdings from trading activity
      items << build_item(label_key: :change_in_holdings_buys_sells, value: net_non_cash_flow, tooltip_key: :investment_change_in_holdings_buys_sells, style: :flow)

      # Market price changes
      items << build_item(label_key: :change_in_holdings_market_activity, value: balance.net_market_flows_money, tooltip_key: :investment_change_in_holdings_market_activity, style: :flow)

      if has_adjustments?
        items << build_item(label_key: :end_balance, value: end_balance_before_adjustments, tooltip_key: :investment_end_balance_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: total_adjustments, tooltip_key: :manual_adjustments, style: :adjustment)
      end

      items << build_item(label_key: :final_balance, value: balance.end_balance_money, tooltip_key: :investment_final_portfolio_value_day, style: :final)
      items
    end

    def loan_items
      items = [
        build_item(label_key: :start_principal, value: balance.start_balance_money, tooltip_key: :loan_principal_start_day, style: :start),
        build_item(label_key: :net_principal_change, value: net_non_cash_flow, tooltip_key: :loan_net_principal_change_day, style: :flow)
      ]

      if has_adjustments?
        items << build_item(label_key: :end_principal, value: end_balance_before_adjustments, tooltip_key: :loan_end_principal_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: balance.non_cash_adjustments_money, tooltip_key: :manual_adjustments, style: :adjustment)
      end

      items << build_item(label_key: :final_principal, value: balance.end_balance_money, tooltip_key: :loan_final_principal_day, style: :final)
      items
    end

    def asset_items # Property/Vehicle
      items = [
        build_item(label_key: :start_value, value: balance.start_balance_money, tooltip_key: :asset_value_start_day, style: :start),
        build_item(label_key: :net_value_change, value: net_total_flow, tooltip_key: :asset_net_value_change_day, style: :flow)
      ]

      if has_adjustments?
        items << build_item(label_key: :end_value, value: end_balance_before_adjustments, tooltip_key: :asset_end_value_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: total_adjustments, tooltip_key: :asset_manual_adjustments_appraisals, style: :adjustment)
      end

      items << build_item(label_key: :final_value, value: balance.end_balance_money, tooltip_key: :asset_final_value_day, style: :final)
      items
    end

    def crypto_items
      items = [
        build_item(label_key: :start_balance, value: balance.start_balance_money, tooltip_key: :crypto_holdings_value_start_day, style: :start)
      ]

      items << build_item(label_key: :buys, value: balance.cash_outflows_money * -1, tooltip_key: :crypto_purchases_day, style: :flow) if balance.cash_outflows != 0
      items << build_item(label_key: :sells, value: balance.cash_inflows_money, tooltip_key: :crypto_sales_day, style: :flow) if balance.cash_inflows != 0
      items << build_item(label_key: :market_changes, value: balance.net_market_flows_money, tooltip_key: :crypto_market_price_changes, style: :flow) if balance.net_market_flows != 0

      if has_adjustments?
        items << build_item(label_key: :end_balance, value: end_balance_before_adjustments, tooltip_key: :crypto_end_balance_calculated, style: :subtotal)
        items << build_item(label_key: :adjustments, value: total_adjustments, tooltip_key: :manual_adjustments, style: :adjustment)
      end

      items << build_item(label_key: :final_balance, value: balance.end_balance_money, tooltip_key: :crypto_final_holdings_value_day, style: :final)
      items
    end

    def net_cash_flow
      balance.cash_inflows_money - balance.cash_outflows_money
    end

    def net_non_cash_flow
      balance.non_cash_inflows_money - balance.non_cash_outflows_money
    end

    def net_total_flow
      net_cash_flow + net_non_cash_flow + balance.net_market_flows_money
    end

    def total_adjustments
      balance.cash_adjustments_money + balance.non_cash_adjustments_money
    end

    def has_adjustments?
      balance.cash_adjustments != 0 || balance.non_cash_adjustments != 0
    end

    def end_balance_before_adjustments
      balance.end_balance_money - total_adjustments
    end

    def build_item(label_key:, value:, tooltip_key:, style:)
      {
        label: I18n.t("balance_reconciliation.labels.#{label_key}"),
        value: value,
        tooltip: I18n.t("balance_reconciliation.tooltips.#{tooltip_key}"),
        style: style
      }
    end
end
