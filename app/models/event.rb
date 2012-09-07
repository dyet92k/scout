class Event
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type
  field :description
  field :data, type: Hash

  index :type

  scope :for_time, ->(start, ending) {where(created_at: {"$gt" => Time.zone.parse(start).midnight, "$lt" => Time.zone.parse(ending).midnight})}

  def self.unsubscribe!(interest)
    create!(
      type: "unsubscribe-alert", 
      description: "#{interest.user.contact} from #{interest.in}", 
      data: interest.attributes.dup
    )
  end

  def self.email_failed!(tag, to, subject, body)
    create!(
      type: "email-failed",
      description: "Postmark down, SMTP failed also",
      data: {
        tag: tag, to: to, subject: subject, body: body
      }
    )
  end

  def self.postmark_bounce!(email, bounce_type, details)
    user = User.where(email: email).first

    stop = %w{ SpamComplaint SpamNotification BadEmailAddress Blocked }
    unsubscribed = false
    if stop.include?(bounce_type)
      unsubscribed = true
      if user
        user.notifications = "none"
        user.save!
      end
    end

    event = create!(
      type: "postmark-bounce",
      description: "#{bounce_type} for #{email}",
      data: details,
      user_id: user ? user.id : nil,
      unsubscribed: unsubscribed
    )

    # email admin
    Admin.bounce_report event.description, event.attributes.dup
  end
end