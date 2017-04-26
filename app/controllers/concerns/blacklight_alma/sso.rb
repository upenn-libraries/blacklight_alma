
require 'securerandom'

module BlacklightAlma

  # module to be mixed in to a Devise::SessionController. Provides callback function
  # for single-sign on.
  #
  # See the section "SAML based SSO" on this page:
  # https://developers.exlibrisgroup.com/alma/integrations/discovery/fulfillment_services
  #
  module Sso

    extend ActiveSupport::Concern

    # This action is typically a path protected behind Shibboleth authentication.
    # After the user has authenticated with a SSO service, they return to this app,
    # hitting this action for real, which logs them into discovery and redirects them to the URL
    # specified by 'next' param.
    def sso_login_callback
      next_url = params[:next] || '/'

      email = sso_get_user || 'unknown email address'
      user = sso_login_user_model.find_or_create_by(email: email) do |user|
        sso_login_fill_new_user(user)
      end

      sign_in(:user, user)
      # set warden user manually
      env['warden'].set_user(user)

      sso_login_populate_session

      redirect_to next_url
    end

    def sso_login_populate_session
      session[:alma_auth_type] = 'sso'
      session[:alma_sso_user] = sso_get_user
      session[:alma_sso_token] = SecureRandom.hex(10)
    end

    # @return [Class] class object to use for users
    def sso_login_user_model
      User
    end

    # This gets called on newly created User objects
    # so that they can be filled
    def sso_login_fill_new_user(user)
      # no-op
    end

    # override if user identifier is in another http header
    # or determined some other way
    def sso_get_user
      request.headers['HTTP_REMOTE_USER']
    end
  end

end
