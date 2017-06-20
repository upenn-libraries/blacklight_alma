/**
 * BlacklightAlma is a Javascript class for integration with Alma.
 * AJAX calls are made to endpoints on the Rails server that
 * in turn communicate with Alma.
 */

var BlacklightAlma = function (options) {
    options = options || {};
    this.MAX_AJAX_ATTEMPTS = options.maxAjaxAttempts || 3;
};

/**
 * Subclasses should override to customize. To filter out a holding from display,
 * this function can return null.
 * @param holding
 * @returns {string}
 */
BlacklightAlma.prototype.formatHolding = function (mms_id, holding) {
    if(holding['inventory_type'] == 'physical') {
        var libraryAndLocation = [holding['library'], holding['location']].join(" - ");
        return [holding['availability'], libraryAndLocation, holding['call_number']]
            .filter(function (item) {
                return item != null && item.length > 0;
            }).join(". ");
    }
    else if(holding['inventory_type'] == 'digital') {
        var joined = [holding['institution'], holding['repository_name'], holding['label'], holding['representation']]
            .filter(function (item) {
                return item != null && item.length > 0;
            }).join(" - ");
        return joined || "Digital Resource (no other information available)";
    }
    else if(holding['inventory_type'] == 'electronic') {
        var url = null;
        if(holding['link_to_service_page']) {
            var text = holding['collection'] || "Electronic resource";
            url = '<a href="' + holding['link_to_service_page'] + '">' + text + '</a>';
        }
        url = url || "Electronic Resource (no URL available)";
        return [url, holding['coverage_statement']]
            .filter(function (item) {
                return item != null && item.length > 0;
            }).join(" - ");
    }
};

/**
 * Subclasses should override to customize.
 * @param holding
 * @returns {string}
 */
BlacklightAlma.prototype.formatHoldings = function (holdings) {
    return holdings.join("<br/>");
};

/**
 * Populates html document with availability status strings
 * @param data
 */
BlacklightAlma.prototype.populateAvailability = function () {
    var baObj = this;

    var idsLoaded = Object.keys(baObj.availability);

    $(".availability-ajax-load").filter(function(index, element) {
        return ! $(element).hasClass("availability-ajax-loaded");
    }).each(function (index, element) {
        var idString = $(element).data("availabilityIds").toString() || "";
        var ids = idString.split(",").filter(function(s) { return s.length > 0; });

        // make sure we have data for ALL the ids (this accounts for bibs w/ multiple holdings
        // across boundwiths), otherwise we're not ready to populate yet.
        if(ids.filter(function(id) { return idsLoaded.includes(id); }).length != ids.length) {
            return;
        }

        // jquery's map auto-flattens and strips out nulls
        var html = $.map(ids, function(id) {
            if (baObj.availability[id]) {
                var holdings = baObj.availability[id]['holdings'] || [];
                if (holdings.length > 0) {
                    var formatted = $.map(holdings, function(holding) {
                        return baObj.formatHolding(id, holding);
                    });
                    return baObj.formatHoldings(formatted);
                }
            }
        }).join("<br/>");

        baObj.renderAvailability(element, html);
    });
};

/**
 * Renders the passed-in html on the given element
 * @param element
 * @param html
 */
BlacklightAlma.prototype.renderAvailability = function(element, html) {
    $(element).addClass("availability-ajax-loaded");
    $(element).html(html);
};

/**
 * Subclasses should override to customize.
 */
BlacklightAlma.prototype.errorLoadingAvailability = function () {
    $(".availability-ajax-load").html("<span style='color: red'>Error loading status for this item</span>");
};

/**
 * Shows elements with class indicating that they should be shown
 * after availability is loaded on the page.
 */
BlacklightAlma.prototype.showElementsOnAvailabilityLoad = function () {
    $(".availability-show-on-ajax-load").removeClass("hide").show();
};

/**
 * Actually makes the AJAX call for availability
 * @param idList
 * @param attemptCount
 */
BlacklightAlma.prototype.loadAvailabilityAjax = function (idList, attemptCount) {
    var baObj = this;
    if(idList.length > 0) {
        var url = "/alma/availability.json?id_list=" + encodeURIComponent(idList);
        console.log(url);
        $.ajax(url, {
            success: function(data, textStatus, jqXHR) {
                if(!data.error) {
                    console.log(data);
                    baObj.availability = Object.assign(baObj.availability, data['availability']);
                    baObj.populateAvailability();
                } else {
                    console.log("Attempt #" + attemptCount + " error loading availability: " + data.error);
                    // errors here aren't necessary "fatal", they could be temporary
                    if(attemptCount < baObj.MAX_AJAX_ATTEMPTS) {
                        baObj.loadAvailabilityAjax(idList, attemptCount + 1);
                    } else {
                        baObj.errorLoadingAvailability();
                    }
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                console.log("Attempt #" + attemptCount + " error loading availability: " + textStatus + ", " + errorThrown);
                if(errorThrown !== 'timeout') {
                    if(attemptCount < baObj.MAX_AJAX_ATTEMPTS) {
                        baObj.loadAvailabilityAjax(idList, attemptCount + 1);
                    } else {
                        baObj.errorLoadingAvailability();
                    }
                }
            },
            complete: function() {
                baObj.showElementsOnAvailabilityLoad();

                baObj.availabilityRequestsFinished[idList] = true;
            }
        });
    }
};

/**
 * Adds click listeners to elements that should toggle the availability details
 * (iframe) for the associated document (determined by shared parent class).
 * This is used for search results page.
 */
BlacklightAlma.prototype.registerToggleAvailabilityDetails = function() {
    var baObj = this;

    $(".availability-toggle-details").click(function (event) {
        var toggleElement = event.currentTarget;

        $(event.currentTarget).closest(".availability-document-container").find(".availability-details-container").each(function(idx, element) {
            baObj.toggleAvailabilityDetailsForRecord(toggleElement, element);
        });
    });
};


BlacklightAlma.prototype.createIframeElement = function(url) {
    var iframe = $("<iframe>");
    iframe.attr("class", "availability-details-iframe");
    iframe.attr("title", "Show availability for this record");
    iframe.attr("src", url);
    iframe.attr("style", "width: 100%");
    return iframe;
};

/**
 * Toggles an individual record's availability details (shown in an iframe)
 */
BlacklightAlma.prototype.toggleAvailabilityDetailsForRecord = function(toggleElement, containerElement) {
    var baObj = this;
    var newTextForToggle;
    if ($(containerElement).find("iframe").length == 0) {
        var url = $(containerElement).data("availabilityIframeUrl");
        var iframe = baObj.createIframeElement(url);
        $(containerElement).html(iframe);
        newTextForToggle = $(toggleElement).data("hideText");
    } else {
        $(containerElement).find("iframe").remove();
        newTextForToggle = $(toggleElement).data("showText");
    }
    $(toggleElement).html(newTextForToggle);
};

/**
 * Partitions an array into arrays of specified size
 * @param size
 * @param arr
 * @returns {*}
 */
BlacklightAlma.prototype.partitionArray = function(size, arr) {
    return arr.reduce(function(acc, a, b) {
        if(b % size == 0  && b !== 0) {
            acc.push([]);
        }
        acc[acc.length - 1].push(a);
        return acc;
    }, [[]]);
};

/**
 * Looks for elements with class availability-ajax-load,
 * batches up the values in their data-availability-id attribute,
 * makes the AJAX request, and replaces the contents
 * of the element with availability information.
 */
BlacklightAlma.prototype.loadAvailability = function() {
    var baObj = this;

    baObj.availability = {};
    baObj.availabilityRequestsFinished = {};

    this.registerToggleAvailabilityDetails();

    var allIds = $(".availability-ajax-load").map(function (index, element) {
        return $(element).data("availabilityIds");
    }).get();

    var idArrays = this.partitionArray(10, allIds);

    idArrays.forEach(function(idArray) {
        var idArrayStr = idArray.join(",");
        baObj.availabilityRequestsFinished[idArrayStr] = false;
        baObj.loadAvailabilityAjax(idArrayStr, 1);
    });

    baObj.checkAndPopulateMissing();
};

/**
 * Periodically checks for all AJAX availability requests to finish, then displays
 * messages for records that we couldn't load availability info for.
 */
BlacklightAlma.prototype.checkAndPopulateMissing = function() {

    var baObj = this;
    for(key in baObj.availabilityRequestsFinished) {
        if(!baObj.availabilityRequestsFinished[key]) {
            setTimeout(function() { baObj.checkAndPopulateMissing(); }, 1000);
            return;
        }
    }

    $(".availability-ajax-load").filter(function(index, element) {
        return ! $(element).hasClass("availability-ajax-loaded");
    }).each(function (index, element) {
        $(element).html("<span style='color: red'>No status available for this item</span>");
    });
};
