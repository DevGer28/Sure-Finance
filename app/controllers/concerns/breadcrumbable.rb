module Breadcrumbable
  extend ActiveSupport::Concern

  included do
    before_action :set_breadcrumbs
  end

  private
    # The default, unless specific controller or action explicitly overrides
    def set_breadcrumbs
      @breadcrumbs = [ breadcrumb_root, breadcrumb_item(controller_name) ]
    end

    def breadcrumb_root
      [ breadcrumb_label(:home), root_path ]
    end

    def breadcrumb_item(key, path = nil)
      [ breadcrumb_label(key), path ]
    end

    def breadcrumb_label(key)
      t("breadcrumbs.#{key}", default: key.to_s.tr("_", " ").titleize)
    end
end
