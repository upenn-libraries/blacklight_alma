require 'uri'

module BlacklightAlma
  module ApplicationHelper

    # document = SolrDocument
    def alma_app_fulfillment_url(document)
      # See https://developers.exlibrisgroup.com/alma/integrations/discovery/fulfillment_services
      mms_id = document.id
      domain = ENV['ALMA_DELIVERY_DOMAIN'] || 'alma.delivery.domain.example.com'
      institution_code = ENV['ALMA_INSTITUTION_CODE'] || 'INSTITUTION_CODE'
      URI::HTTPS.build(
        host: domain,
        path: "/view/uresolver/#{institution_code}/openurl",
        query: {
          rfr_id: 'info:sid/primo.exlibrisgroup.com',
          svc_dat: 'getit',
          'rft.mms_id': mms_id,
        }.to_query).to_s
    end

  end
end
