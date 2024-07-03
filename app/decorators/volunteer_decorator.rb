class VolunteerDecorator < UserDecorator
  include Draper::LazyHelpers

  def cc_reminder_text
    if h.current_user.supervisor?
      "Send CC to Supervisor"
    elsif h.current_user.casa_admin?
      "Send CC to Supervisor and Admin"
    end
  end

  def casa_case_links
    safe_join(casa_cases.ordered.map { |cc| link_to cc.case_number, cc, data: { turbo: false } }, ", ".html_safe)
  end

  def status_text
    active? ? "Active" : "Inactive"
  end

  def last_attempted_contact_link
    return unless volunteer.last_case_contact

    link_to volunteer.last_case_contact.occurred_at.strftime("%B %d, %Y"), volunteer.last_case_contact.casa_case, data: { turbo: false }
  end

  def transition_youth_text
    has_transition_aged_youth_cases? ? 'Yes 🦋' : 'No 🐛'
  end

  # todo - yuri, need help with cleaning up n+1 here
  # logic came from VolunteerDatatable
  def has_transition_aged_youth_cases?
    case_assignments.joins(:casa_case).where(casa_cases:  {birth_month_year_youth: ..CasaCase::TRANSITION_AGE.years.ago})
                    .active.count.positive?
  end

  def extra_languages_text
    return if extra_languages.count == 0

    "<span class='language-icon' data-toggle='tooltip' title='#{extra_languages.join(', ')}'>🌎</span>".html_safe
  end
end
