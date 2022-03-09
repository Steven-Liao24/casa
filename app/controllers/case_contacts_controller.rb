# frozen_string_literal: true

class CaseContactsController < ApplicationController
  before_action :set_case_contact, only: %i[edit update destroy]
  before_action :set_contact_types, only: %i[new edit update create]
  before_action :require_organization!
  after_action :verify_authorized

  def index
    authorize CaseContact

    @current_organization_groups = current_organization_groups

    @filterrific = initialize_filterrific(
      all_case_contacts,
      params[:filterrific],
      select_options: {
        sorted_by: CaseContact.options_for_sorted_by
      }
    ) || return

    case_contacts = @filterrific.find.group_by(&:casa_case_id)

    @presenter = CaseContactPresenter.new(case_contacts)
  end

  def new
    authorize CaseContact
    @casa_cases = policy_scope(current_organization.casa_cases)

    # Admins and supervisors who are navigating to this page from a specific
    # case detail page will only see that case as an option
    if params.dig(:case_contact, :casa_case_id).present?
      @casa_cases = @casa_cases.where(id: params.dig(:case_contact, :casa_case_id))
    end

    @case_contact = CaseContact.new

    # By default the first case is selected
    @selected_cases = @casa_cases[0, 1]

    @selected_case_contact_types = @selected_cases.flat_map(&:contact_types)

    @current_organization_groups =
      if @selected_case_contact_types.present?
        @selected_case_contact_types.map(&:contact_type_group).uniq
      else
        current_organization
          .contact_type_groups
          .joins(:contact_types)
          .where(contact_types: {active: true})
          .alphabetically
          .uniq
      end
  end

  def create
    # These variables are used to re-render the form (render :new) if there are
    # validation errors so that the user does not lose inputs to fields that
    # they did previously enter.

    @casa_cases = policy_scope(current_organization.casa_cases)
    @case_contact = CaseContact.new(create_case_contact_params)
    authorize @case_contact
    @current_organization_groups = current_organization.contact_type_groups

    @selected_cases = @casa_cases.where(id: params.dig(:case_contact, :casa_case_id))
    if @selected_cases.empty?
      flash[:alert] = t("case_min_validation", scope: "case_contact")
      render :new
      return
    end

    # Create a case contact for every case that was checked
    case_contacts = create_case_contact_for_every_selected_casa_case(@selected_cases)
    if case_contacts.all?(&:persisted?)
      redirect_to casa_case_path(CaseContact.last.casa_case, success: true)
    else
      @case_contact = case_contacts.first
      @casa_cases = [@case_contact.casa_case]
      render :new
    end
  end

  def edit
    authorize @case_contact
    current_user.notifications.unread.where(id: params[:notification_id]).mark_as_read!
    @casa_cases = [@case_contact.casa_case]
    @selected_cases = @casa_cases
    @current_organization_groups = current_organization.contact_type_groups
  end

  def update
    authorize @case_contact
    @casa_cases = [@case_contact.casa_case]
    @selected_cases = @casa_cases
    @current_organization_groups = current_organization.contact_type_groups

    if @case_contact.update_cleaning_contact_types(update_case_contact_params)
      if additional_expense_params&.any? && FeatureFlagService.is_enabled?(FeatureFlagService::SHOW_ADDITIONAL_EXPENSES_FLAG)
        additional_expense_params.each do |ae_params|
          update_or_create_additional_expense(ae_params)
        end
      end
      if @case_contact.valid?
        redirect_to casa_case_path(@case_contact.casa_case), notice: t("update", scope: "case_contact")
      else
        render :edit
      end
    else
      render :edit
    end
  end

  def destroy
    authorize CasaAdmin

    @case_contact.destroy
    flash[:notice] = t("destroy", scope: "case_contact")
    redirect_to request.referer
  end

  def restore
    authorize CasaAdmin

    case_contact = authorize(current_organization.case_contacts.with_deleted.find(params[:id]))
    case_contact.restore(recrusive: true)
    flash[:notice] = t("restore", scope: "case_contact")
    redirect_to request.referer
  end

  private

  def update_or_create_additional_expense(ae_params)
    id = ae_params[:id]
    current = AdditionalExpense.find_by(id: id)
    if current
      current.assign_attributes(other_expense_amount: ae_params[:other_expense_amount], other_expenses_describe: ae_params[:other_expenses_describe])
      current.valid? ? current.save : @case_contact.errors.add(:base, current.errors.full_messages.to_sentence)
    else
      create_new_exp = @case_contact.additional_expenses.build(ae_params)
      create_new_exp.valid? ? create_new_exp.save : @case_contact.errors.add(:base, create_new_exp.errors.full_messages.to_sentence)
    end
  end

  def create_case_contact_for_every_selected_casa_case(selected_cases)
    # create case contact and additional expense
    selected_cases.map do |casa_case|
      new_cc = casa_case.case_contacts.build(create_case_contact_params)
      if FeatureFlagService.is_enabled?(FeatureFlagService::SHOW_ADDITIONAL_EXPENSES_FLAG)
        create_additional_expenses(new_cc)
      end
      new_cc
    end
  end

  def create_additional_expenses(new_cc)
    additional_expense_params.map { |aep|
      new_ae = new_cc.additional_expenses.build(aep)
      if new_ae.valid?
        new_ae.save!
      else
        new_cc.errors.add(:base, new_ae.errors.full_messages.to_sentence)
      end
    }
  end

  def set_case_contact
    if current_organization.case_contacts.exists?(params[:id])
      @case_contact = authorize(current_organization.case_contacts.find(params[:id]))
    else
      redirect_to authenticated_user_root_path
    end
  end

  def set_contact_types
    @contact_types = ContactType.for_organization(current_organization)
  end

  def create_case_contact_params
    CaseContactParameters.new(params, creator: current_user)
  end

  def update_case_contact_params
    # Updating a case contact should not change its original creator
    CaseContactParameters.new(params)
  end

  def current_organization_groups
    current_organization.contact_type_groups
      .joins(:contact_types)
      .where(contact_types: {active: true})
      .uniq
  end

  def all_case_contacts
    policy_scope(current_organization.case_contacts).includes(:creator, contact_types: :contact_type_group)
  end

  def additional_expense_params
    additional_expenses = params.dig("case_contact", "additional_expenses_attributes")
    additional_expenses && 0.upto(10).map do |i|
      possible_key = i.to_s
      if additional_expenses&.key?(possible_key) && additional_expenses[i.to_s]["other_expense_amount"].present?
        additional_expenses[i.to_s]&.permit(:other_expense_amount, :other_expenses_describe, :id)
      end
    end.compact
  end
end
