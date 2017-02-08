
# Blacklight_Alma

[Blacklight](https://github.com/projectblacklight/blacklight) integration with [Alma](https://developers.exlibrisgroup.com/alma).

This gem is designed to be minimally invasive, making available code
that your project must choose to use.

# How to use this

Include this in your app's Gemfile.

```ruby
gem 'blacklight_alma', :git => 'https://github.com/upenn-libraries/blacklight_alma.git'
gem 'ezwadl', :git => 'https://github.com/upenn-libraries/ezwadl.git'
```

For the features below to work, you'll need to set the following
environment variables:

```
ALMA_DELIVERY_DOMAIN = hostname of alma instance
ALMA_INSTITUTION_CODE = institution code
ALMA_API_KEY = api key
ALMA_AUTH_SECRET = used for social auth, copy the value from Alma configuration
```

# Features

## Availability via AJAX

This feature allows you to populate HTML elements with availability
status by loading that information via AJAX.

Edit your `application.js` file to include the js library for the
BlacklightAlma object:

```
//= require blacklight_alma/blacklight_alma
```

Create or edit your project's `/app/helpers/catalog_helper.rb` to get BlacklightAlma 
overrides:

```ruby
module CatalogHelper
  include Blacklight::CatalogHelperBehavior
  include BlacklightAlma::CatalogOverride
end
```

Create a new js file in your project containing these lines so that
the availability code is triggered on page load.

```javascript
$(document).ready(function() {
    var ba = new BlacklightAlma();
    ba.loadAvailability();
});
```

Use the Availability concern in an existing controller, create a new
controller using it, or use the stock
`BlacklightAlma::AlmaController`. If you choose the last option,
remember to add it to your `routes.rb` file, like so:

```
scope module: 'blacklight_alma' do
  get 'alma/availability' => 'alma#availability'
end
```

In your view (typically `_index_default.html.erb`), add the HTML
classes and attributes needed to trigger status loading via AJAX.

```html
<dl class="document-metadata dl-horizontal dl-invert">
  <!-- ... stock blacklight code not shown here... --> 
  <dt class="blacklight-availability">Status/Location:</dt>
  <dd class="blacklight-availability availability-ajax-load" data-availability-id="<%= document.id %>">Loading...</dd>
  <dt class="availability-show-on-ajax-load hide"></dt>
  <dd class="availability-show-on-ajax-load hide">
    <button class="btn btn-default availability-toggle-details" data-show-text="Show Availability Details" data-hide-text="Hide Availability Details">Show Availability Details</button>
  </dd>
</dl>

<div class="availability-details-container" data-availability-iframe-url="<%= alma_app_fulfillment_url(document) %>"></div>
```

## Fulfillment iframe

Add something like this to your show view (`_show_default.html.erb`, usually):

```html
  <iframe src="<%= alma_app_fulfillment_url(document) %>" style="width: 100%"></iframe>
```

## Social Login

See this [blog post](https://developers.exlibrisgroup.com/blog/Leveraging-Social-Login-with-Alma) for information
about how to implement Alma's social login feature.

This gem can integrate social login with Devise.

In your project, create a subclass of `Devise::SessionsController` if you don't already have one. If you do,
then just include the `BlacklightAlma::SocialLogin` module. See that module for things you can override.

```ruby
class SessionsController < Devise::SessionsController
  include BlacklightAlma::SocialLogin
end
```

Modify your `routes.rb` file as follows:

```ruby
# tell devise to use your SessionsController
devise_for :users, controllers: { sessions: 'sessions' }

# set up the route for the callback, which is needed for the
# alma_social_login_url helper to work
devise_scope :user do
  get 'alma/social_login_callback' => 'sessions#social_login_callback'
end
```

Create your HTML link to login using the social login.

```html
<a href="<%= alma_social_login_url %>">Login using a Google account</a>
```
