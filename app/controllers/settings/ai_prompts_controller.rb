class Settings::AiPromptsController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [ breadcrumb_root, breadcrumb_item(:ai_prompts) ]
    @family = Current.family
    @assistant_config = Assistant.config_for(OpenStruct.new(user: Current.user))
  end
end
