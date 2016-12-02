
# Stock controller that apps can use as an alternative to including
# modules.
module BlacklightAlma
  class AlmaController < ActionController::Base

    include BlacklightAlma::Availability

  end

end
