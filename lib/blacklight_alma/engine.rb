module BlacklightAlma
  class Engine < ::Rails::Engine
    isolate_namespace BlacklightAlma

    initializer 'blacklight_alma.helpers' do |app|
      ActionView::Base.send :include, BlacklightAlmaHelper
    end

  end
end
