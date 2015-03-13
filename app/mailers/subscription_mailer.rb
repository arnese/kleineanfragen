class SubscriptionMailer < ApplicationMailer
  helper ApplicationHelper
  after_action :set_send_at

  def papers(subscription, papers)
    @subscription = subscription
    @papers = Paper.where(id: papers)

    subject = 'neue kleine Anfragen'

    if @subscription.subtype == 'body'
      body = Body.find_by_state(@subscription.query)
      subject = "#{@papers.size} neue kleine Anfrage#{@papers.size == 1 ? '' : 'n'} aus #{body.name}"
    end

    headers['List-Unsubscribe'] = "<#{unsubscribe_url}>"
    mail subject: subject, to: @subscription.email
  end

  private

  def unsubscribe_url
    Rails.application.routes.url_helpers.unsubscribe_url(@subscription, Rails.configuration.action_mailer.default_url_options)
  end

  def set_send_at
    @subscription.last_sent_at = DateTime.now
    @subscription.save
  end
end
