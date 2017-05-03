
module BlacklightAlma

  # module to be mixed in to controllers
  module Availability

    extend ActiveSupport::Concern

    def alma_api_class
      BlacklightAlma::AvailabilityApi
    end

    # controller action AJAX endpoint for fetching availability information
    # for one or more ids
    def availability
      if params[:id_list].present?
        api = alma_api_class.new()
        response_data = api.get_availability(params[:id_list].split(','))
      else
        response_data = {
            'error' => 'No id_list parameter'
        }
      end

      respond_to do |format|
        format.xml  { render :xml => response_data }
        format.json { render :json => response_data }
      end
    end

  end

end
