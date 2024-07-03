# frozen_string_literal: true

class Table::HeaderComponent < ViewComponent::Base
  def initialize(title:, method: nil, base_path: nil)
    @title = title
    @method = method
    @base_path = base_path
  end

  def before_render
    set_full_path
    set_ascending
  end

  def set_full_path
    return unless @base_path

    @path =  Rails.application.routes.url_helpers.send("#{@base_path}_path", order: @method, asc: !ascending?, search: params[:search])
  end

  def set_ascending
    @ascending = ascending?
  end

  def ascending?
    ["true", true].include?(params[:asc])
  end

end
