require 'uri'

module BlacklightAlma
  module HelperBehavior

    def alma_domain
      ENV['ALMA_DELIVERY_DOMAIN'] || 'alma.delivery.domain.example.com'
    end

    def alma_institution_code
      ENV['ALMA_INSTITUTION_CODE'] || 'INSTITUTION_CODE'
    end

    # Lower-level function to build an openurl URL. used by other helpers,
    # you shouldn't need to call this directly from application code.
    #
    # @param query [Hash] this gets merged into a hash of defaults
    def alma_build_openurl(query)
      query_defaults = {
        rfr_id: 'info:sid/primo.exlibrisgroup.com',
      }

      URI::HTTPS.build(
          host: alma_domain,
          path: "/view/uresolver/#{alma_institution_code}/openurl",
          query: query_defaults.merge(query).to_query).to_s
    end

    # Returns a URL to be used in an iframe
    # See https://developers.exlibrisgroup.com/alma/integrations/discovery/fulfillment_services
    #
    # @param document [SolrDocument]
    # @param service_type [String] viewit, getit
    # @param language [String] language code
    # @param view [Int] integer code for view to use. From documentation:
    # "In order to support multiple views, an institution can define multiple views
    # in Alma, with different CSS. This is configured in Alma under
    # Gerenal configuration - Delivery System Skins."
    # @return [String] url
    def alma_app_fulfillment_url(document, service_type: nil, language: nil, view: nil)
      mms_id = document.respond_to?(:alma_mms_id) ? document.alma_mms_id : document.id
      service_type ||= alma_service_type_for_fulfillment_url(document)

      query = {
          svc_dat: service_type,
          'rft.mms_id': mms_id,
      }
      rft_dat_value = [language.present? ? "language=#{language}" : nil,
                       view.present? ? "view=#{view}" : nil].compact.join(',')
      query['rft_dat'] = rft_dat_value if rft_dat_value.present?
      query['u.ignore_date_coverage'] = 'true' if service_type == 'viewit'

      if session[:alma_auth_type] == 'sso' && session[:alma_sso_token].present?
        query['sso'] = 'true'
        query['token'] = session[:alma_sso_token]
      elsif session[:alma_social_login_provider].present?
        query['oauth'] = 'true'
        query['provider'] = session[:alma_social_login_provider]
      end

      alma_build_openurl(query)
    end

    # Returns the right service type string depending on whether
    # the document (bib record) is electronic or not.
    # TODO: This doesn't account for fact that a bib record may have both
    # physical and electronic holdings. Need to figure out how to handle that:
    # the view creating the iframe may need to check holdings/availability first,
    # which isn't ideal since it's an additional request.
    # @param document [SolrDocument]
    # @return [String] viewit, getit
    def alma_service_type_for_fulfillment_url(document)
      if (document['format'] || '').downcase == 'electronic'
        'viewit'
      else
        'getit'
      end
    end

    def alma_electronic_resource_direct_link(portfolio_pid)
      query = {
          'u.ignore_date_coverage': 'true',
          'Force_direct': true,
          portfolio_pid: portfolio_pid
      }
      alma_build_openurl(query)
    end

    def alma_social_login_url(backUrl=nil)
      if backUrl.nil?
        # alma_social_login_callback_url should be either manually
        # defined in a helper or auto-defined by a route
        if respond_to? :alma_social_login_callback_url
          backUrl = alma_social_login_callback_url
        else
          raise "alma_social_login_callback_url helper method not found"
        end
      end
      query = {
          institutionCode: alma_institution_code,
          backUrl: backUrl
      }
      URI::HTTPS.build(
          host: alma_domain,
          path: '/view/socialLogin',
          query: query.to_query).to_s
    end

  end
end
