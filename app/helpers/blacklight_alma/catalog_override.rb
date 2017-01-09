
module BlacklightAlma

  # Overrides for CatalogHelper.
  # This should be included in the main app's CatalogHelper
  module CatalogOverride

    # add 'availability-document-container' class to document
    def render_document_class(document = @document)
      result = super(document)
      [result, 'availability-document-container'].join(' ')
    end

  end
end
