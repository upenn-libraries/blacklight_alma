
module BlacklightAlma

  # These are main entry points for interacting with the API
  # at a fairly high level. This code is decoupled from Rails/Blacklight
  # enough that it should be usable from standalone scripts and such.
  class AvailabilityApi

    # see https://developers.exlibrisgroup.com/alma/apis/bibs/GET/gwPcGly021om4RTvtjbPleCklCGxeYAf3JPdiJpJhUA=/af2fb69d-64f4-42bc-bb05-d8a0ae56936e
    @inventory_type_to_subfield_codes_to_fieldnames = {
        'AVA' => {
            'INVENTORY_TYPE' => 'physical',
            'a' => 'institution',
            'b' => 'library_code',
            'c' => 'location',
            'd' => 'call_number',
            'e' => 'availability',
            'f' => 'total_items',
            'g' => 'non_available_items',
            'j' => 'location_code',
            'k' => 'call_number_type',
            'p' => 'priority',
            'q' => 'library',
            't' => 'holding_info',
            '8' => 'holding_id',
        },
        'AVD' => {
            'INVENTORY_TYPE' => 'digital',
            'a' => 'institution',
            'b' => 'representations_id',
            'c' => 'representation',
            'd' => 'repository_name',
            'e' => 'label',
        },
        'AVE' => {
            'INVENTORY_TYPE' => 'electronic',
            'c' => 'collection_id',
            'e' => 'activation_status',
            'l' => 'library_code',
            'm' => 'collection',
            'n' => 'public_note',
            's' => 'coverage_statement',
            't' => 'interface_name',
            'u' => 'link_to_service_page',
            '8' => 'portfolio_pid',
        }
    }

    class << self
      attr_accessor :inventory_type_to_subfield_codes_to_fieldnames
    end

    # @return [Hash] data structure describing holdings of bib ids
    def parse_bibs_data(api_response)
      # make sure bibs is always an Array
      bibs = [ api_response['bibs']['bib'] ].flatten(1)

      inventory_types = AvailabilityApi.inventory_type_to_subfield_codes_to_fieldnames.keys

      bibs.map do |bib|
        record = Hash.new
        record['mms_id'] = bib['mms_id']

        inventory_fields = bib.fetch('record', Hash.new).fetch('datafield', []).select { |df| inventory_types.member?(df['tag']) } || []

        record['holdings'] = inventory_fields.map do |inventory_field|
          inventory_type = inventory_field['tag']
          subfield_codes_to_fieldnames = AvailabilityApi.inventory_type_to_subfield_codes_to_fieldnames[inventory_type]

          # make sure subfields is always an Array (which isn't the case if there's only one subfield element)
          subfields = [ inventory_field.fetch('subfield', []) ].flatten(1)

          holding = subfields.reduce(Hash.new) do |acc, subfield|
            fieldname = subfield_codes_to_fieldnames[subfield['code']]
            fieldvalue = subfield['__content__']
            if fieldname
              acc[fieldname] = fieldvalue
            end
            acc
          end
          holding['inventory_type'] = subfield_codes_to_fieldnames['INVENTORY_TYPE']
          holding = transform_holding(holding)
          holding
        end
        record
      end.reduce(Hash.new) do |acc, avail|
        acc[avail['mms_id']] = avail.select { |k,v| k != 'mms_id' }
        acc
      end
    end

    # this hook allows for transformation of the holding record after
    # it's been populated using the Alma API response data
    # and the codes have been mapped to human readable names.
    # @param holding [Hash]
    # @return [Hash] the modified or new holding
    def transform_holding(holding)
      holding
    end

    # @param id_list [Array] array of id strings
    def get_availability(id_list)
      api_params = {
          'mms_id' => id_list.map(&:to_s).map(&:strip).join(','),
          'expand' => 'p_avail,e_avail,d_avail'
      }

      api_response = BlacklightAlma::BibsApi.instance.get_availability(api_params)

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
          Blacklight.logger.error("ALMA JSON response contains error code=#{api_response}")
          response_data = {
             # not clear why it's called 'errorList', could value be an array sometimes? not sure.
             # for this reason, we pass it wholesale.
              'error' => web_service_result['errorList'].present? ? web_service_result['errorList'] : 'Unknown error from ALMA API'
          }
        end
      else
        response_data = {
            'error' => 'Error making request to ALMA, received no data in response'
        }
      end
      response_data
    end

  end

end
