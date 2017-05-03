
module BlacklightAlma

  class BibsApi < BaseApi

    def self.wadl
      'bibs.wadl'
    end

    def get_availability(params)
      request(ezwadl_api[0].almaws_v1_bibs, :get, params)
    end

  end

end
