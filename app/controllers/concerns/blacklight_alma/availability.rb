
module BlacklightAlma

  module Availability

    include ActiveSupport::Benchmarkable

    @subfield_codes_to_fieldnames = {
      'q' => 'library',
      'c' => 'location',
      'd' => 'call_number',
      'e' => 'status',
    }

    class << self
      attr_accessor :subfield_codes_to_fieldnames
    end

    # returns an Array of bib items and their holdings
    def parse_bibs_data(api_response)
      # make sure bibs is always an Array
      bibs = api_response['bibs']['bib']
      if bibs.is_a?(Hash)
        bibs = [ bibs ]
      end

      bibs.map do |bib|
        record = Hash.new
        record['mms_id'] = bib['mms_id']
        ava_fields = bib.fetch('record', Hash.new).fetch('datafield', []).select { |df| df['tag'] == 'AVA'} || []
        record['holdings'] = ava_fields.map do |ava_field|
          ava_field.fetch('subfield', []).reduce(Hash.new) do |acc, subfield|
            fieldname = Availability.subfield_codes_to_fieldnames[subfield['code']]
            acc[fieldname] = subfield['__content__']
            acc
          end
        end
        record
      end.reduce(Hash.new) do |acc, avail|
        acc[avail['mms_id']] = avail.select { |k,v| k != 'mms_id' }
        acc
      end
    end

    def availability
      if params[:id_list].present?
        id_list = params[:id_list].split(',').map(&:strip).join(',')

        api_params = {
          'mms_id' => id_list,
          'expand' => 'p_avail,e_avail,d_avail',
          'apikey' => ENV['ALMA_API_KEY'],
        }

        Blacklight.logger.debug("ALMA API availability query: #{api_params}")

        api_response = benchmark('ALMA API availability request', level: :debug) do
          BlacklightAlma::Api.instance.ezwadl_api[0].almaws_v1_bibs.get({ query: api_params })
        end

        if api_response
          web_service_result = api_response['web_service_result']
          if !web_service_result
            begin
              availability = parse_bibs_data(api_response)
            rescue Exception => e
              Blacklight.logger.error("Error parsing ALMA response: #{e}, response data=#{api_response}")
            end
            response_data = {
              'availability' => availability
            }
          else
            # Errors look like this:
            # { "web_service_result"=>
            #   { "errorsExist"=>"true",
            #     "errorList"=>
            #       {"error"=>
            #         {"errorCode"=>"INTERNAL_SERVER_ERROR",
            #          "errorMessage"=>"\nThe web server encountered an unexpected condition that prevented it from fulfilling the request. If the error persists, please use the unique tracking ID when reporting it.",
            #          "trackingId"=>"..."
            #         }
            #       }
            #   }
            # }
            response_data = {
              'error' => "ALMA error: #{web_service_result['errorList']}"
            }
          end
        else
          response_data = {
            'error' => 'No id_list parameter'
          }
        end
      else
        response_data = {
          'error' => 'Error making request to ALMA, received no data in response'
        }
      end

      respond_to do |format|
        format.xml  { render :xml => response_data }
        format.json { render :json => response_data }
      end
    end

  end

end
