
require 'singleton'
require 'benchmark'

require 'ezwadl'

module BlacklightAlma

  # Base class for all Api classes. An Api class centers around a .wadl file.
  # Subclasses should be instantiated as singletons using #instance.
  class BaseApi
    include Singleton

    attr_accessor :ezwadl_api

    # Subclasses should implement this class-level method.
    # @return [String] filename of the wadl to use
    def self.wadl
      raise 'This should never get called'
    end

    def initialize
      @ezwadl_api = EzWadl::Parser.parse(BlacklightAlma::Engine.root.join('wadl', self.class.wadl))
    end

    # Subclasses should implement this class-level method.
    # @param [EzWadl::Resource] resource object to use for making request
    # @param [Symbol] request_type only :get is supported right now
    # @param [Hash] params parameters for the API http request
    # @return [HTTParty::Response] response object
    def request(resource, request_type, params)
      api_params = process_params(params)
      Blacklight.logger.debug("ALMA API request: wadl=#{self.class.wadl} resource=#{resource.path} params=#{api_params}")
      response = nil
      time = Benchmark.measure do
        response = resource.send(request_type.to_sym, { query: api_params })
      end
      Blacklight.logger.debug("ALMA API request took (#{(time.real * 1000).to_i}ms)")
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
