
require 'singleton'

module BlacklightAlma
  class Api
    include Singleton

    attr_accessor :ezwadl_api

    def initialize
      @ezwadl_api = EzWadl::Parser.parse(BlacklightAlma::Engine.root.join('wadl', 'api.wadl'))
    end

  end
end
