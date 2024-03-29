require 'mongoid'
require 'activity_notification/apis/notification_api'

module ActivityNotification
  module ORM
    module Mongoid
      # Notification model implementation generated by ActivityNotification.
      class Notification
        include ::Mongoid::Document
        include ::Mongoid::Timestamps
        include ::Mongoid::Attributes::Dynamic
        include GlobalID::Identification
        include Common
        include Renderable
        include Association
        include NotificationAPI
        store_in collection: ActivityNotification.config.notification_table_name

        # Belongs to target instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Target instance of this notification
        belongs_to_polymorphic_xdb_record :target, store_with_associated_records: true

        # Belongs to notifiable instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Notifiable instance of this notification
        belongs_to_polymorphic_xdb_record :notifiable, store_with_associated_records: true

        # Belongs to group instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Group instance of this notification
        belongs_to_polymorphic_xdb_record :group

        field :key,            type: String
        field :parameters,     type: Hash,     default: {}
        field :opened_at,      type: DateTime
        field :group_owner_id, type: String

        # Belongs to group owner notification instance of this notification.
        # Only group member instance has :group_owner value.
        # Group owner instance has nil as :group_owner association.
        # @scope instance
        # @return [Notification] Group owner notification instance of this notification
        belongs_to :group_owner, { class_name: "ActivityNotification::Notification" }.merge(Rails::VERSION::MAJOR >= 5 ? { optional: true } : {})

        # Has many group member notification instances of this notification.
        # Only group owner instance has :group_members value.
        # Group member instance has nil as :group_members association.
        # @scope instance
        # @return [Mongoid::Criteria<Notificaion>] Database query of the group member notification instances of this notification
        has_many   :group_members, class_name: "ActivityNotification::Notification", foreign_key: :group_owner_id

        # Belongs to :otifier instance of this notification.
        # @scope instance
        # @return [Object] Notifier instance of this notification
        belongs_to_polymorphic_xdb_record :notifier, store_with_associated_records: true

        validates  :target,        presence: true
        validates  :notifiable,    presence: true
        validates  :key,           presence: true

        # Selects filtered notifications by type of the object.
        # Filtering with ActivityNotification::Notification is defined as default scope.
        # @return [Mongoid::Criteria<Notification>] Database query of filtered notifications
        default_scope -> { where(_type: "ActivityNotification::Notification") }

        # Selects group owner notifications only.
        # @scope class
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :group_owners_only,                 -> { where(:group_owner_id.exists => false) }

        # Selects group member notifications only.
        # @scope class
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :group_members_only,                -> { where(:group_owner_id.exists => true) }

        # Selects unopened notifications only.
        # @scope class
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :unopened_only,                     -> { where(:opened_at.exists => false) }

        # Selects opened notifications only without limit.
        # Be careful to get too many records with this method.
        # @scope class
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :opened_only!,                      -> { where(:opened_at.exists => true) }

        # Selects opened notifications only with limit.
        # @scope class
        # @param [Integer] limit Limit to query for opened notifications
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :opened_only,                       ->(limit) { limit == 0 ? none : opened_only!.limit(limit) }

        # Selects group member notifications in unopened_index.
        # @scope class
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :unopened_index_group_members_only, -> { where(:group_owner_id.in => unopened_index.map(&:id)) }

        # Selects group member notifications in opened_index.
        # @scope class
        # @param [Integer] limit Limit to query for opened notifications
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :opened_index_group_members_only,   ->(limit) { where(:group_owner_id.in => opened_index(limit).map(&:id)) }

        # Selects notifications within expiration.
        # @scope class
        # @param [ActiveSupport::Duration] expiry_delay Expiry period of notifications
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :within_expiration_only,            ->(expiry_delay) { where(:created_at.gt => expiry_delay.ago) }

        # Selects group member notifications with specified group owner ids.
        # @scope class
        # @param [Array<String>] owner_ids Array of group owner ids
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :group_members_of_owner_ids_only,   ->(owner_ids) { where(:group_owner_id.in => owner_ids) }

        # Selects filtered notifications by target instance.
        #   ActivityNotification::Notification.filtered_by_target(@user)
        # is the same as
        #   @user.notifications
        # @scope class
        # @param [Object] target Target instance for filter
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :filtered_by_target,                ->(target) { filtered_by_association("target", target) }

        # Selects filtered notifications by notifiable instance.
        # @example Get filtered unopened notificatons of the @user for @comment as notifiable
        #   @notifications = @user.notifications.unopened_only.filtered_by_instance(@comment)
        # @scope class
        # @param [Object] notifiable Notifiable instance for filter
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :filtered_by_instance,              ->(notifiable) { filtered_by_association("notifiable", notifiable) }

        # Selects filtered notifications by group instance.
        # @example Get filtered unopened notificatons of the @user for @article as group
        #   @notifications = @user.notifications.unopened_only.filtered_by_group(@article)
        # @scope class
        # @param [Object] group Group instance for filter
        # @return [Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :filtered_by_group,                 ->(group) {
          group.present? ?
            where(group_id: group.id, group_type: group.class.name) :
            any_of({ :group_id.exists => false, :group_type.exists => false }, { group_id: nil, group_type: nil })
        }

        # Selects filtered notifications later than specified time.
        # @example Get filtered unopened notificatons of the @user later than @notification
        #   @notifications = @user.notifications.unopened_only.later_than(@notification.created_at)
        # @scope class
        # @param [Time] Created time of the notifications for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>, Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :later_than,                        ->(created_time) { where(:created_at.gt => created_time) }

        # Selects filtered notifications earlier than specified time.
        # @example Get filtered unopened notificatons of the @user earlier than @notification
        #   @notifications = @user.notifications.unopened_only.earlier_than(@notification.created_at)
        # @scope class
        # @param [Time] Created time of the notifications for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>, Mongoid::Criteria<Notificaion>] Database query of filtered notifications
        scope :earlier_than,                      ->(created_time) { where(:created_at.lt => created_time) }

        # Includes target instance with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with target
        scope :with_target,                       -> { }

        # Includes notifiable instance with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with notifiable
        scope :with_notifiable,                   -> { }

        # Includes group instance with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with group
        scope :with_group,                        -> { }

        # Includes group owner instances with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with group owner
        scope :with_group_owner,                  -> { }

        # Includes group member instances with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with group members
        scope :with_group_members,                -> { }

        # Includes notifier instance with query for notifications.
        # @return [Mongoid::Criteria<Notificaion>] Database query of notifications with notifier
        scope :with_notifier,                     -> { }

        # Dummy reload method for test of notifications.
        scope :reload,                            -> { }

        # Returns if the notification is group owner.
        # Calls NotificationAPI#group_owner? as super method.
        # @return [Boolean] If the notification is group owner
        def group_owner?
          super
        end

        # Raise ActivityNotification::DeleteRestrictionError for notifications.
        # @param [String] error_text Error text for raised exception
        # @raise [ActivityNotification::DeleteRestrictionError] DeleteRestrictionError from used ORM
        # @return [void]
        def self.raise_delete_restriction_error(error_text)
          raise ActivityNotification::DeleteRestrictionError, error_text
        end

        protected

          # Returns count of group members of the unopened notification.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          # @todo Avoid N+1 call
          #
          # @return [Integer] Count of group members of the unopened notification
          def unopened_group_member_count
            group_members.unopened_only.count
          end

          # Returns count of group members of the opened notification.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          # @todo Avoid N+1 call
          #
          # @param [Integer] limit Limit to query for opened notifications
          # @return [Integer] Count of group members of the opened notification
          def opened_group_member_count(limit = ActivityNotification.config.opened_index_limit)
            limit == 0 and return 0
            group_members.opened_only(limit).to_a.length #.count(true)
          end

          # Returns count of group member notifiers of the unopened notification not including group owner notifier.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          # @todo Avoid N+1 call
          #
          # @return [Integer] Count of group member notifiers of the unopened notification
          def unopened_group_member_notifier_count
            group_members.unopened_only
                         .where(notifier_type: notifier_type)
                         .where(:notifier_id.ne => notifier_id)
                         .distinct(:notifier_id)
                         .count
          end

          # Returns count of group member notifiers of the opened notification not including group owner notifier.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          # @todo Avoid N+1 call
          #
          # @param [Integer] limit Limit to query for opened notifications
          # @return [Integer] Count of group member notifiers of the opened notification
          def opened_group_member_notifier_count(limit = ActivityNotification.config.opened_index_limit)
            limit == 0 and return 0
            group_members.opened_only(limit)
                         .where(notifier_type: notifier_type)
                         .where(:notifier_id.ne => notifier_id)
                         .distinct(:notifier_id)
                         .to_a.length #.count(true)
          end

      end
    end
  end
end
