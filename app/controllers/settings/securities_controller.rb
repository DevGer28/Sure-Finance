class Settings::SecuritiesController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [ breadcrumb_root, breadcrumb_item(:security) ]
    @oidc_identities = Current.user.oidc_identities.order(:provider)
  end
end
