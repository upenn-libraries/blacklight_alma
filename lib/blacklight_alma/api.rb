
module BlacklightAlma

  # These are main entry points for interacting with the API
  # at a fairly high level. This code is decoupled from Rails/Blacklight
  # enough that it should be usable from standalone scripts and such.
  class Api

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
            'l' => 'library_code',
            'm' => 'collection',
            'n' => 'public_note',
            's' => 'coverage_statement',
            't' => 'interface_name',
            'u' => 'link_to_service_page',
        }
    }

    class << self
      attr_accessor :inventory_type_to_subfield_codes_to_fieldnames
    end

    # @return [Hash] data structure describing holdings of bib ids
    def parse_bibs_data(api_response)
      # make sure bibs is always an Array
      bibs = api_response['bibs']['bib']
      if bibs.is_a?(Hash)
        bibs = [ bibs ]
      end

      inventory_types = Api.inventory_type_to_subfield_codes_to_fieldnames.keys

      bibs.map do |bib|
        record = Hash.new
        record['mms_id'] = bib['mms_id']

        inventory_fields = bib.fetch('record', Hash.new).fetch('datafield', []).select { |df| inventory_types.member?(df['tag']) } || []

        record['holdings'] = inventory_fields.map do |inventory_field|
          inventory_type = inventory_field['tag']
          subfield_codes_to_fieldnames = Api.inventory_type_to_subfield_codes_to_fieldnames[inventory_type]

          # make sure subfields is always an Array (which isn't the case if there's only one subfield element)
          subfields = inventory_field.fetch('subfield', [])
          if subfields.is_a?(Hash)
            subfields = [ subfields ]
          end

          holding = subfields.reduce(Hash.new) do |acc, subfield|
            fieldname = subfield_codes_to_fieldnames[subfield['code']]
            acc[fieldname] = subfield['__content__']
            acc
          end
          holding['inventory_type'] = subfield_codes_to_fieldnames['INVENTORY_TYPE']
          holding
        end
        record
      end.reduce(Hash.new) do |acc, avail|
        acc[avail['mms_id']] = avail.select { |k,v| k != 'mms_id' }
        acc
      end
    end

    # @param id_list [Array] array of id strings
    def get_availability(id_list)
      api_params = {
          'mms_id' => id_list.map(&:to_s).map(&:strip).join(','),
          'expand' => 'p_avail,e_avail,d_avail'
      }

      api_response = BlacklightAlma::BasicApi.instance.get_availability(api_params)

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
              'error' => "ALMA error: #{web_service_result['errorList']}"
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
