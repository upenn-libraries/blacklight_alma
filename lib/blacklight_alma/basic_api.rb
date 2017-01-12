
require 'singleton'
require 'benchmark'

require 'ezwadl'

module BlacklightAlma

  # This is a "low-level" class that mainly uses ezwadl
  # to make requests and return minimally-processed responses.
  class BasicApi
    include Singleton

    attr_accessor :ezwadl_api

    def initialize
      @ezwadl_api = EzWadl::Parser.parse(BlacklightAlma::Engine.root.join('wadl', 'api.wadl'))
    end

    # @return [Hash|Array] rubyfied response
    def get_availability(params)
      api_params = process_params(params)
      Blacklight.logger.debug("ALMA API availability query: #{api_params}")
      response = nil
      time = Benchmark.measure do
        response = ezwadl_api[0].almaws_v1_bibs.get({ query: api_params })
      end
      Blacklight.logger.debug("ALMA API availability request (#{(time.real * 1000).to_i}ms)")
      response
    end

    def process_params(p)
      params = p.dup
      if !params.member?('apikey')
        params['apikey'] = ENV['ALMA_API_KEY']
      end
      params
    end

  end
end
