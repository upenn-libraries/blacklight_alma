
module BlacklightAlma

  class UsersApi < BaseApi

    def self.wadl
      'users.wadl'
    end

    def get_name(id)
      request(ezwadl_api[0].almaws_v1_users.user_id, :get, { user_id: id })
    end

  end

end
