require 'state_machine'
# coding: utf-8
class Project < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  include PgSearch
  extend CatarseAutoHtml

  before_save do
    if online_days_changed? || !self.expires_at.present?
      self.expires_at = DateTime.now+(online_days rescue 0).days
    end
  end

  mount_uploader :uploaded_image, LogoUploader

  delegate :display_status, :display_progress, :display_image, :display_expires_at,
    :display_pledged, :display_goal, :remaining_days, :progress_bar, :video_embed_url,
    :to => :decorator

  schema_associations
  belongs_to :user
  has_many :backers, :dependent => :destroy
  has_many :rewards, :dependent => :destroy
  has_many :updates, :dependent => :destroy
  has_many :notifications, :dependent => :destroy

  has_and_belongs_to_many :channels

  has_one :project_total
  accepts_nested_attributes_for :rewards

  catarse_auto_html_for field: :about, video_width: 600, video_height: 403

  pg_search_scope :pg_search, against: [
      [:name, 'A'],
      [:headline, 'B'],
      [:about, 'C']
    ],
    associated_against:  {user: [:name, :address_city ]},
    :using => {tsearch: {:dictionary => "portuguese"}},
    ignoring: :accents

  scope :by_progress, ->(progress) { joins(:project_total).where("project_totals.pledged >= projects.goal*?", progress.to_i/100.to_f) }
  scope :by_state, ->(state) { where(state: state) }
  scope :by_id, ->(id) { where(id: id) }
  scope :by_permalink, ->(p) { where(permalink: p) }
  scope :by_category_id, ->(id) { where(category_id: id) }
  scope :name_contains, ->(term) { where("unaccent(upper(name)) LIKE ('%'||unaccent(upper(?))||'%')", term) }
  scope :user_name_contains, ->(term) { joins(:user).where("unaccent(upper(users.name)) LIKE ('%'||unaccent(upper(?))||'%')", term) }
  scope :order_table, ->(sort) {
    if sort == 'desc'
      order('goal desc')
    elsif sort == 'asc'
      order('goal asc')
    else
      order('created_at desc')
    end
  }

  scope :visible, where("state NOT IN ('draft', 'rejected')")
  scope :financial, where("(expires_at > current_timestamp - '15 days'::interval) AND (state in ('online', 'successful', 'waiting_funds'))")
  scope :recommended, where(recommended: true)
  scope :expired, where("expires_at < current_timestamp")
  scope :not_expired, where("expires_at >= current_timestamp")
  scope :expiring, not_expired.where("expires_at < (current_timestamp + interval '2 weeks')")
  scope :not_expiring, not_expired.where("NOT (expires_at < (current_timestamp + interval '2 weeks'))")
  scope :recent, where("current_timestamp - projects.online_date <= '15 days'::interval")
  scope :successful, where(state: 'successful')
  scope :online, where(state: 'online')
  scope :recommended_for_home, ->{
    includes(:user, :category, :project_total).
    recommended.
    visible.
    not_expired.
    order('random()').
    limit(4)
  }
  scope :order_for_search, ->{ reorder("
                                     CASE state
                                     WHEN 'online' THEN 1
                                     WHEN 'waiting_funds' THEN 2
                                     WHEN 'successful' THEN 3
                                     WHEN 'failed' THEN 4
                                     END ASC, created_at DESC, id DESC") }
  scope :expiring_for_home, ->(exclude_ids){
    includes(:user, :category, :project_total).where("coalesce(id NOT IN (?), true)", exclude_ids).visible.expiring.order('date(expires_at), random()').limit(3)
  }
  scope :recent_for_home, ->(exclude_ids){
    includes(:user, :category, :project_total).where("coalesce(id NOT IN (?), true)", exclude_ids).visible.recent.not_expiring.order('date(created_at) DESC, random()').limit(3)
  }
  scope :backed_by, ->(user_id){
    where("id IN (SELECT project_id FROM backers b WHERE b.confirmed AND b.user_id = ?)", user_id)
  }

  validates :video_url, presence: true, if: ->(p) { p.state_name == 'online' }
  validates_presence_of :name, :user, :category, :about, :headline, :goal, :permalink
  validates_length_of :headline, :maximum => 140
  validates_numericality_of :online_days, :less_than_or_equal_to => 60
  validates_uniqueness_of :permalink, :allow_blank => true, :allow_nil => true, :case_sensitive => false
  validates_format_of :permalink, with: /^(\w|-)*$/, :allow_blank => true, :allow_nil => true
  validates_format_of :video_url, with: Regexp.union(/https?:\/\/(www\.)?vimeo.com\/(\d+)/, VideoInfo::Youtube.new('').regex), message: I18n.t('project.video_regex_validation'), allow_blank: true
  mount_uploader :video_thumbnail, LogoUploader

  def self.between_created_at(start_at, ends_at)
    return scoped unless start_at.present? && ends_at.present?
    where("created_at between to_date(?, 'dd/mm/yyyy') and to_date(?, 'dd/mm/yyyy')", start_at, ends_at)
  end

  def self.between_expires_at(start_at, ends_at)
    return scoped unless start_at.present? && ends_at.present?
    where("expires_at between to_date(?, 'dd/mm/yyyy') and to_date(?, 'dd/mm/yyyy')", start_at, ends_at)
  end

  def self.finish_projects!
    expired.each do |resource|
      Rails.logger.info "[FINISHING PROJECT #{resource.id}] #{resource.name}"
      resource.finish
    end
  end

  def self.state_names
    self.state_machine.states.map &:name
  end

  def subscribed_users
    User.subscribed_to_updates.subscribed_to_project(self.id)
  end

  def decorator
    @decorator ||= ProjectDecorator.new(self)
  end

  def video
    @video ||= VideoInfo.get(self.video_url) if self.video_url.present?
  end

  def to_param
    "#{self.id}-#{self.name.parameterize}"
  end

  def pledged
    project_total ? project_total.pledged : 0.0
  end

  def total_backers
    project_total ? project_total.total_backers : 0
  end

  def selected_rewards
    rewards.sort_asc.where(id: backers.confirmed.select('DISTINCT(reward_id)'))
  end

  def reached_goal?
    pledged >= goal
  end

  def finished?
    not online? and not draft? and not rejected?
  end

  # NOTE: I think that we just can look the expires_at column
  # the project enter on finished / failed state when expires ;)
  def expired?
    expires_at < Time.now
  end

  def in_time_to_wait?
    backers.in_time_to_confirm.count > 0
  end

  def in_time?
    !expired?
  end

  def progress
    return 0 if goal == 0.0 && pledged == 0.0
    return 100 if goal == 0.0 && pledged > 0.0
    ((pledged / goal * 100).abs).round(pledged.to_i.size).to_i
  end

  def time_to_go
    ['day', 'hour', 'minute', 'second'].each do |unit|
      if expires_at >= 1.send(unit).from_now
        time = ((expires_at - Time.now).abs/1.send(unit)).round
        return {time: time, unit: pluralize_without_number(time, I18n.t("datetime.prompts.#{unit}").downcase)}
      end
    end
    {time: 0, unit: pluralize_without_number(0, I18n.t('datetime.prompts.second').downcase)}
  end

  def remaining_text
    pluralize_without_number(time_to_go[:time], I18n.t('remaining_singular'), I18n.t('remaining_plural'))
  end

  def download_video_thumbnail
    self.video_thumbnail = open(self.video.thumbnail_large) if self.video_url
  rescue OpenURI::HTTPError => e
    ::Airbrake.notify({ :error_class => "Video thumbnail download", :error_message => "Video thumbnail download: #{e.inspect}", :parameters => video_url}) rescue nil
  rescue TypeError => e
    ::Airbrake.notify({ :error_class => "Carrierwave does not like thumbnail file", :error_message => "Carrierwave does not like thumbnail file: #{e.inspect}", :parameters => video_url}) rescue nil
  end

  def as_json(options={})
    {
      id: id,
      name: name,
      user: user,
      category: category,
      image: display_image,
      headline: headline,
      progress: progress,
      display_progress: display_progress,
      pledged: display_pledged,
      created_at: created_at,
      time_to_go: time_to_go,
      remaining_text: remaining_text,
      embed_url: video ? video.embed_url : nil,
      url: Rails.application.routes.url_helpers.project_by_slug_path(permalink, :locale => I18n.locale),
      full_uri: Rails.application.routes.url_helpers.project_by_slug_url(permalink, :locale => I18n.locale),
      expired: expired?,
      successful: successful? || reached_goal?,
      waiting_funds: waiting_funds?,
      display_status_to_box: display_status.blank? ? nil : I18n.t("project.display_status.#{display_status}"),
      display_expires_at: display_expires_at,
      in_time: in_time?
    }
  end

  def pending_backers_reached_the_goal?
    (pledged + backers.in_time_to_confirm.sum(&:value)) >= goal
  end

  def can_go_to_second_chance?
    (pledged + backers.in_time_to_confirm.sum(&:value)) >= (goal*0.3.to_f)
  end

  #NOTE: state machine things
  state_machine :state, :initial => :draft do
    state :draft, value: 'draft'
    state :rejected, value: 'rejected'
    state :online, value: 'online'
    state :successful, value: 'successful'
    state :waiting_funds, value: 'waiting_funds'
    state :failed, value: 'failed'

    event :push_to_draft do
      transition all => :draft #NOTE: when use 'all' we can't use new hash style ;(
    end

    event :reject do
      transition draft: :rejected
    end

    event :approve do
      transition draft: :online
    end

    event :finish do
      transition online: :failed,             if: ->(project) {
        project.expired? && !project.pending_backers_reached_the_goal? && !project.can_go_to_second_chance?
      }

      transition online: :waiting_funds,      if: ->(project) {
        project.expired? && (project.pending_backers_reached_the_goal? || project.can_go_to_second_chance?)
      }

      transition waiting_funds: :successful,  if: ->(project) {
        project.reached_goal? && !project.in_time_to_wait?
      }

      transition waiting_funds: :failed,      if: ->(project) {
        project.expired? && !project.reached_goal? && !project.in_time_to_wait?
      }

      transition waiting_funds: :waiting_funds,      if: ->(project) {
        project.expired? && !project.reached_goal? && project.in_time_to_wait?
      }
    end

    after_transition online: :waiting_funds, do: :after_transition_of_online_to_waiting_funds
    after_transition online: :failed, do: :after_transition_of_online_to_failed
    after_transition waiting_funds: [:successful, :failed], do: :after_transition_of_wainting_funds_to_successful_or_failed
    after_transition waiting_funds: :successful, do: :after_transition_of_wainting_funds_to_successful
    after_transition draft: :online, do: :after_transition_of_draft_to_online
    after_transition draft: :rejected, do: :after_transition_of_draft_to_rejected
    after_transition any => [:failed, :successful], :do => :after_transition_of_any_to_failed_or_successful
    after_transition :waiting_funds => [:failed, :successful], :do => :after_transition_of_waiting_funds_to_failed_or_successful
  end

  def after_transition_of_online_to_waiting_funds
    notify_observers :notify_owner_that_project_is_waiting_funds
  end

  def after_transition_of_waiting_funds_to_failed_or_successful
    notify_observers :notify_admin_that_project_reached_deadline
  end

  def after_transition_of_any_to_failed_or_successful
    notify_observers :sync_with_mailchimp
  end

  def after_transition_of_online_to_failed
    notify_observers :notify_users
  end

  def after_transition_of_wainting_funds_to_successful
    notify_observers :notify_owner_that_project_is_successful
  end

  def after_transition_of_draft_to_rejected
    notify_observers :notify_owner_that_project_is_rejected
  end

  def after_transition_of_wainting_funds_to_successful_or_failed
    notify_observers :notify_users
  end

  def after_transition_of_draft_to_online
    update_attributes({ online_date: DateTime.now, expires_at: (DateTime.now + online_days.days) })
    notify_observers :notify_owner_that_project_is_online
  end

  def new_draft_recipient
    email = (channels.first.email rescue nil) || ::Configuration[:email_projects]
    User.where(email: email).first
  end

  def new_draft_project_notification_type
    channels.first ? :new_draft_project_channel : :new_draft_project
  end

  def new_project_received_notification_type
    channels.first ? :project_received_channel : :project_received
  end
end
