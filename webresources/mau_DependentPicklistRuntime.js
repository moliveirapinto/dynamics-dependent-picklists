/*
 * mau_DependentPicklistRuntime.js
 * Runtime form script for Salesforce-style dependent picklists in model-driven apps.
 *
 * Usage:
 *   1) Add this web resource to the form library.
 *   2) Register MauDependentPicklists.onFormLoad on the form's OnLoad event,
 *      with "Pass execution context as first parameter" enabled.
 *
 * It will:
 *   - Read all active rules for the current entity from mau_dependentpicklistrule.
 *   - For every (controlling, dependent) pair found:
 *       a) Hook the controlling field's OnChange.
 *       b) Apply the filter immediately on load.
 *   - When the controlling value is empty or no matching rule exists, the dependent
 *     field shows ALL its options (i.e. unrestricted).
 *   - When the controlling value matches a rule, only allowed values remain in the
 *     dependent option set; if the current dependent value is no longer allowed,
 *     it is cleared.
 */
"use strict";
var MauDependentPicklists = (function () {
    var _cache = {}; // entityLogicalName -> rules array
    var _originalOptions = {}; // formId|fieldName -> original option array

    function log() {
        try { if (window && window.console) console.log.apply(console, ["[DepPicklists]"].concat([].slice.call(arguments))); } catch (e) { }
    }

    function fetchRules(entityLogicalName) {
        if (_cache[entityLogicalName]) {
            return Promise.resolve(_cache[entityLogicalName]);
        }
        var qs = "?$select=mau_controllingfieldlogicalname,mau_dependentfieldlogicalname,mau_controllingoptionvalue,mau_alloweddependentoptionvalues,mau_formid" +
            "&$filter=mau_entitylogicalname eq '" + entityLogicalName + "' and mau_isactive eq true";
        return Xrm.WebApi.online.retrieveMultipleRecords("mau_dependentpicklistrule", qs).then(function (res) {
            _cache[entityLogicalName] = res.entities || [];
            return _cache[entityLogicalName];
        }, function (err) {
            log("Rule fetch error", err);
            _cache[entityLogicalName] = [];
            return [];
        });
    }

    function _normalizeFormId(s) {
        return String(s || '').replace(/[{}]/g, '').toLowerCase();
    }

    function _getCurrentFormId(formContext) {
        // Try multiple sources because formSelector is not always populated
        // (e.g., when a single form is available, on some custom apps, or
        // depending on UCI version). Order matters: most reliable first.
        try {
            if (formContext && formContext.ui && formContext.ui.formSelector
                && typeof formContext.ui.formSelector.getCurrentItem === 'function') {
                var item = formContext.ui.formSelector.getCurrentItem();
                if (item && typeof item.getId === 'function') {
                    var id = item.getId();
                    if (id) { log("formId via formSelector:", id); return _normalizeFormId(id); }
                }
            }
        } catch (e) { log("formSelector error", e); }
        // Newer UCI: page context exposes the form id directly.
        try {
            if (window.Xrm && Xrm.Utility && typeof Xrm.Utility.getPageContext === 'function') {
                var pc = Xrm.Utility.getPageContext();
                if (pc && pc.input && pc.input.formId) {
                    log("formId via getPageContext:", pc.input.formId);
                    return _normalizeFormId(pc.input.formId);
                }
            }
        } catch (e) { log("getPageContext error", e); }
        // Last resort: parse the &formid= parameter from the page URL.
        try {
            var href = (window.parent && window.parent.location && window.parent.location.href) || window.location.href;
            var m = /[?&#]formid=([^&]+)/i.exec(href || '');
            if (m && m[1]) {
                var decoded = decodeURIComponent(m[1]);
                log("formId via URL:", decoded);
                return _normalizeFormId(decoded);
            }
        } catch (e) { log("URL formId error", e); }
        log("Could not determine current form id; falling back to entity-wide rules.");
        return '';
    }

    // Given the full rules array for the entity and a (controlling, dependent)
    // pair, return the rules to apply on this form. Form-specific rules
    // (mau_formid === currentFormId) take precedence per pair: if any exist,
    // entity-wide rules for that same pair are ignored on this form.
    function _rulesForPair(allRules, controllingField, dependentField, currentFormId) {
        var same = allRules.filter(function (r) {
            return r.mau_controllingfieldlogicalname === controllingField
                && r.mau_dependentfieldlogicalname === dependentField;
        });
        var formSpecific = same.filter(function (r) {
            return r.mau_formid && _normalizeFormId(r.mau_formid) === currentFormId;
        });
        if (formSpecific.length) return formSpecific;
        return same.filter(function (r) {
            return !r.mau_formid; // entity-wide (mau_formid is null/empty)
        });
    }

    function snapshotOriginalOptions(formContext, fieldName) {
        var key = fieldName;
        if (_originalOptions[key]) return _originalOptions[key];
        var ctrl = formContext.getControl(fieldName);
        if (!ctrl || !ctrl.getAttribute) return null;
        var attr = ctrl.getAttribute();
        if (!attr || !attr.getOptions) return null;
        // Snapshot with index + color so we can re-insert in original order with color preserved.
        var opts = attr.getOptions().map(function (o, i) {
            return { value: o.value, text: o.text, color: o.color, index: i };
        });
        _originalOptions[key] = opts;
        return opts;
    }

    function applyFilter(formContext, controllingField, dependentField, rules) {
        var depCtrl = formContext.getControl(dependentField);
        if (!depCtrl) { log("Dependent control not found:", dependentField); return; }
        var ctrlAttr = formContext.getAttribute(controllingField);
        if (!ctrlAttr) { log("Controlling attribute not found:", controllingField); return; }

        var original = snapshotOriginalOptions(formContext, dependentField);
        if (!original) { log("Could not snapshot original options for", dependentField); return; }

        var controllingValue = ctrlAttr.getValue();

        // Find matching rule
        var allowed = null; // null means "no restriction"
        if (controllingValue !== null && controllingValue !== undefined) {
            var match = rules.filter(function (r) {
                return r.mau_controllingfieldlogicalname === controllingField
                    && r.mau_dependentfieldlogicalname === dependentField
                    && Number(r.mau_controllingoptionvalue) === Number(controllingValue);
            })[0];
            if (match) {
                var raw = match.mau_alloweddependentoptionvalues;
                if (raw === null || raw === undefined || raw === "") {
                    allowed = [];
                } else {
                    try {
                        var parsed = JSON.parse(raw);
                        if (Array.isArray(parsed)) {
                            allowed = parsed.map(Number);
                        } else {
                            // Scalar number stored without array brackets
                            allowed = [Number(parsed)];
                        }
                    } catch (e) {
                        // Fall back: comma-separated list of numbers
                        allowed = String(raw).split(",").map(function (s) { return Number(s.trim()); }).filter(function (n) { return !isNaN(n); });
                    }
                }
            }
        }

        // Use removeOption-only when restricting, so original option metadata
        // (including color) is preserved on the surviving options. When the
        // restriction loosens (allowed===null or different set), re-insert any
        // missing options at their original index, passing through color.
        try {
            // Determine current option values present on the control
            var attr = depCtrl.getAttribute();
            // NOTE: getOptions() returns the FULL metadata regardless of
            // remove/clear/add calls, so we cannot rely on it to know what is
            // currently rendered. We track our own state per field.
            if (!_originalOptions[dependentField + "__removed"]) {
                _originalOptions[dependentField + "__removed"] = {};
            }
            var removedSet = _originalOptions[dependentField + "__removed"];

            original.forEach(function (opt) {
                var v = Number(opt.value);
                var shouldShow = (allowed === null) || allowed.indexOf(v) !== -1;
                var isRemoved = !!removedSet[v];
                if (shouldShow && isRemoved) {
                    // Re-insert at original index; pass color so badge color survives.
                    var addObj = { value: opt.value, text: opt.text };
                    if (opt.color) { addObj.color = opt.color; }
                    try { depCtrl.addOption(addObj, opt.index); } catch (e1) { depCtrl.addOption(addObj); }
                    delete removedSet[v];
                } else if (!shouldShow && !isRemoved) {
                    try { depCtrl.removeOption(opt.value); removedSet[v] = true; } catch (e2) { log("removeOption failed", opt.value, e2); }
                }
            });
        } catch (e) {
            log("filter apply error", e);
            return;
        }

        // If current dep value is no longer allowed, clear it
        var depAttr = formContext.getAttribute(dependentField);
        if (depAttr) {
            var curVal = depAttr.getValue();
            if (curVal !== null && curVal !== undefined && allowed !== null && allowed.indexOf(Number(curVal)) === -1) {
                depAttr.setValue(null);
                depAttr.fireOnChange();
            }
        }
    }

    function bindPair(formContext, controllingField, dependentField, allRules) {
        // Apply now
        applyFilter(formContext, controllingField, dependentField, allRules);
        // Hook OnChange (avoid duplicate by using a tag on the attribute)
        var ctrlAttr = formContext.getAttribute(controllingField);
        if (!ctrlAttr) return;
        var tag = "_mauDepHook_" + dependentField;
        if (ctrlAttr[tag]) return;
        ctrlAttr[tag] = true;
        ctrlAttr.addOnChange(function () { applyFilter(formContext, controllingField, dependentField, allRules); });
    }

    function onFormLoad(executionContext) {
        try {
            var formContext = executionContext.getFormContext();
            var entityLogicalName = formContext.data.entity.getEntityName();
            var currentFormId = _getCurrentFormId(formContext);
            // Fire-and-forget: apply colors to all picklist fields on the form
            applyChoiceColors(formContext, entityLogicalName);
            fetchRules(entityLogicalName).then(function (rules) {
                if (!rules || !rules.length) { log("No active rules for", entityLogicalName); return; }
                // Build unique pair list
                var pairs = {};
                rules.forEach(function (r) {
                    var k = r.mau_controllingfieldlogicalname + "||" + r.mau_dependentfieldlogicalname;
                    pairs[k] = { c: r.mau_controllingfieldlogicalname, d: r.mau_dependentfieldlogicalname };
                });
                Object.keys(pairs).forEach(function (k) {
                    var p = pairs[k];
                    // Per-pair: use form-specific rules if any exist for this
                    // form; otherwise fall back to entity-wide rules. This lets
                    // admins override one pair on a single form without
                    // copying every rule.
                    var effective = _rulesForPair(rules, p.c, p.d, currentFormId);
                    if (!effective.length) {
                        log("No effective rules for", p.c, "->", p.d, "(formId=" + currentFormId + ")");
                        return;
                    }
                    log("Binding", p.c, "->", p.d, "with", effective.length, "rule(s)",
                        effective[0].mau_formid ? "(form-specific)" : "(entity-wide)");
                    bindPair(formContext, p.c, p.d, effective);
                });
            });
        } catch (e) {
            log("onFormLoad error", e);
        }
    }

    // ---------------- Choice color rendering ----------------
    // Reads color metadata from option set definitions and paints the form
    // controls (combobox + open listbox) for any choice field whose options
    // have a configured color. Works on regular Picklist columns where the
    // standard Dynamics control would otherwise ignore the color metadata.

    function _hexToRgba(hex, alpha) {
        try {
            hex = String(hex).replace('#', '');
            if (hex.length === 3) hex = hex.split('').map(function (c) { return c + c; }).join('');
            var r = parseInt(hex.substr(0, 2), 16);
            var g = parseInt(hex.substr(2, 2), 16);
            var b = parseInt(hex.substr(4, 2), 16);
            return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
        } catch (e) { return hex; }
    }

    function _fetchColorMap(entity, field) {
        var clientUrl = (window.Xrm && Xrm.Utility && Xrm.Utility.getGlobalContext)
            ? Xrm.Utility.getGlobalContext().getClientUrl() : "";
        var url = clientUrl + "/api/data/v9.2/EntityDefinitions(LogicalName='" + entity +
            "')/Attributes(LogicalName='" + field +
            "')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$select=LogicalName&$expand=OptionSet($select=Options)";
        return fetch(url, {
            headers: { 'Accept': 'application/json', 'OData-Version': '4.0', 'OData-MaxVersion': '4.0' },
            credentials: 'include'
        }).then(function (r) { return r.ok ? r.json() : null; }).then(function (data) {
            var byValue = {}; var byText = {};
            var opts = (data && data.OptionSet && data.OptionSet.Options) || [];
            opts.forEach(function (o) {
                if (!o.Color) return;
                var label = (o.Label && o.Label.UserLocalizedLabel && o.Label.UserLocalizedLabel.Label) || String(o.Value);
                byValue[Number(o.Value)] = o.Color;
                byText[label] = o.Color;
            });
            return { byValue: byValue, byText: byText, hasAny: Object.keys(byValue).length > 0 };
        }).catch(function () { return { byValue: {}, byText: {}, hasAny: false }; });
    }

    function applyChoiceColors(formContext, entityLogicalName) {
        try {
            // Map of control display label -> { byValue, byText }
            var colorMaps = {};
            var pendingFields = [];
            formContext.ui.controls.forEach(function (c) {
                try {
                    var ctype = c.getControlType && c.getControlType();
                    if (ctype !== 'optionset' && ctype !== 'standard') return;
                    var attr = c.getAttribute && c.getAttribute();
                    if (!attr || typeof attr.getOptions !== 'function') return;
                    var atype = attr.getAttributeType && attr.getAttributeType();
                    if (atype !== 'optionset' && atype !== 'picklist') return;
                    var label = (c.getLabel && c.getLabel()) || c.getName();
                    if (!label || colorMaps[label]) return;
                    pendingFields.push({ field: attr.getName(), label: label });
                } catch (e) { }
            });
            if (!pendingFields.length) { log("No picklist controls on form to color."); return; }

            Promise.all(pendingFields.map(function (p) {
                return _fetchColorMap(entityLogicalName, p.field).then(function (m) {
                    if (m.hasAny) colorMaps[p.label] = m;
                });
            })).then(function () {
                if (!Object.keys(colorMaps).length) { log("No choice fields on form have colors configured."); return; }
                _startColorObserver(colorMaps);
            });
        } catch (e) {
            log("applyChoiceColors error", e);
        }
    }

    function _findFormDocument() {
        // The Xrm script runs in a sandboxed iframe but the form UI renders in
        // a parent document. Walk up to find the document that actually
        // contains role="combobox" elements.
        var docs = [];
        try { if (window.document) docs.push(window.document); } catch (e) { }
        try { if (window.parent && window.parent !== window && window.parent.document) docs.push(window.parent.document); } catch (e) { }
        try { if (window.top && window.top !== window && window.top.document) docs.push(window.top.document); } catch (e) { }
        for (var i = 0; i < docs.length; i++) {
            try {
                if (docs[i].querySelector('[role="combobox"]')) return docs[i];
            } catch (e) { }
        }
        return window.document;
    }

    function _startColorObserver(colorMaps) {
        var doc = _findFormDocument();

        // Collect every document we should search for listboxes — comboboxes
        // sometimes render their dropdown in a portal layer attached to the
        // top window's body (or a sibling iframe), not the same document as
        // the combobox itself.
        function allSearchDocs() {
            var out = [];
            var seen = new Set();
            function add(d) { if (d && !seen.has(d)) { seen.add(d); out.push(d); } }
            try { add(doc); } catch (e) { }
            try { add(window.document); } catch (e) { }
            try { add(window.parent && window.parent.document); } catch (e) { }
            try { add(window.top && window.top.document); } catch (e) { }
            return out;
        }

        function paintOption(opt, text, color) {
            var bl = '4px solid ' + color;
            var bg = _hexToRgba(color, 0.18);
            if (opt.style.borderLeft !== bl) opt.style.borderLeft = bl;
            if (opt.style.background !== bg) opt.style.background = bg;
            opt.style.borderRadius = '4px';
            opt.style.margin = '2px 0';
            opt.style.cursor = 'pointer';
            opt.dataset.mauColored = text;
        }

        // Inject a single <style> per doc that adds a subtle dark overlay on
        // hover/keyboard-focus of any option we've colored. This survives
        // DOM rebuilds because it targets the [data-mau-colored] attribute.
        var styledDocs = new Set();
        function injectHoverStyle(d) {
            try {
                if (!d || !d.head || styledDocs.has(d)) return;
                styledDocs.add(d);
                var s = d.createElement('style');
                s.setAttribute('data-mau-hover', '1');
                s.textContent =
                    '[data-mau-colored]{transition:box-shadow .08s ease;}' +
                    '[data-mau-colored]:hover,[data-mau-colored][aria-selected="true"]{' +
                    'box-shadow:inset 0 0 0 9999px rgba(0,0,0,0.07)!important;cursor:pointer;}';
                d.head.appendChild(s);
            } catch (e) { }
        }

        function optionText(opt) {
            // Normalize: strip leading checkmark used to indicate the selected
            // entry, collapse whitespace.
            var t = (opt.getAttribute && (opt.getAttribute('aria-label') || opt.getAttribute('title')))
                || opt.textContent || '';
            t = String(t).replace(/^[\u2713\u2714\s]+/, '').trim();
            return t;
        }

        function colorize() {
            var docs = allSearchDocs();
            // 1) Color any open listbox associated with a known combobox label.
            //    We look for *every* open combobox across every doc, then for
            //    every listbox we paint options whose normalized text matches
            //    a color map (by combobox label).
            var openLabels = [];
            docs.forEach(function (d) {
                try {
                    d.querySelectorAll('[role="combobox"][aria-expanded="true"]').forEach(function (cb) {
                        var lbl = cb.getAttribute('aria-label') || '';
                        if (colorMaps[lbl] && openLabels.indexOf(lbl) < 0) openLabels.push(lbl);
                    });
                } catch (e) { }
            });

            if (openLabels.length) {
                docs.forEach(function (d) {
                    try {
                        d.querySelectorAll('[role="listbox"], [role="presentation"] [role="option"]').forEach(function (host) {
                            var listbox = host.getAttribute && host.getAttribute('role') === 'listbox' ? host : host.closest('[role="listbox"]') || host.parentElement;
                            if (!listbox) return;
                            var opts = listbox.querySelectorAll('[role="option"]');
                            opts.forEach(function (opt) {
                                var text = optionText(opt);
                                if (!text || text === '---' || text === '--Select--') return;
                                // Try every open label's color map (we don't always
                                // know which combobox owns this listbox).
                                for (var i = 0; i < openLabels.length; i++) {
                                    var color = colorMaps[openLabels[i]].byText[text];
                                    if (color) { paintOption(opt, text, color); break; }
                                }
                            });
                        });
                    } catch (e) { }
                });
            }

            // 2) Color the selected value display on every known combobox.
            docs.forEach(function (d) {
                try {
                    d.querySelectorAll('[role="combobox"]').forEach(function (cb) {
                        var lbl = cb.getAttribute('aria-label') || '';
                        var map = colorMaps[lbl];
                        if (!map) return;
                        var raw = (cb.textContent || '').trim();
                        if (!raw || raw === '---' || raw === '--Select--') {
                            if (cb.dataset.mauComboColored) {
                                cb.style.borderLeft = ''; cb.style.background = '';
                                delete cb.dataset.mauComboColored;
                            }
                            return;
                        }
                        var matched = null;
                        Object.keys(map.byText).forEach(function (k) {
                            if (raw === k || raw.indexOf(k) === 0) {
                                if (!matched || k.length > matched.length) matched = k;
                            }
                        });
                        if (!matched) return;
                        var color = map.byText[matched];
                        var bl = '3px solid ' + color;
                        var bg = _hexToRgba(color, 0.10);
                        if (cb.style.borderLeft !== bl) cb.style.borderLeft = bl;
                        if (cb.style.background !== bg) cb.style.background = bg;
                        cb.style.borderRadius = '4px';
                        cb.dataset.mauComboColored = matched;
                    });
                } catch (e) { }
            });
        }

        // Initial pass + observer
        colorize();
        var pending = false;
        function schedule() {
            if (pending) return;
            pending = true;
            setTimeout(function () { pending = false; colorize(); }, 30);
        }

        // Observe every searchable document so portal layers in window.top are caught too.
        var observed = new Set();
        function observeAll() {
            allSearchDocs().forEach(function (d) {
                try {
                    injectHoverStyle(d);
                    if (!d.body || observed.has(d.body)) return;
                    observed.add(d.body);
                    new MutationObserver(schedule).observe(d.body, {
                        childList: true, subtree: true, characterData: true,
                        attributes: true,
                        attributeFilter: ['aria-expanded', 'aria-selected', 'aria-activedescendant', 'value', 'title', 'class']
                    });
                } catch (e) { }
            });
        }
        observeAll();
        // New iframes/portals can appear later — re-attach periodically (cheap).
        setInterval(observeAll, 2000);

        // Aggressive polling while any tracked combobox is expanded.
        // Cheap: typically only runs for a fraction of a second at a time.
        setInterval(function () {
            var anyOpen = false;
            allSearchDocs().forEach(function (d) {
                if (anyOpen) return;
                try {
                    var open = d.querySelectorAll('[role="combobox"][aria-expanded="true"]');
                    for (var i = 0; i < open.length; i++) {
                        if (colorMaps[open[i].getAttribute('aria-label') || '']) { anyOpen = true; break; }
                    }
                } catch (e) { }
            });
            if (anyOpen) colorize();
        }, 100);

        // Re-colorize on user interaction with any combobox/listbox.
        ['click', 'keyup', 'change', 'focusin', 'focusout', 'mousedown'].forEach(function (ev) {
            allSearchDocs().forEach(function (d) {
                try {
                    d.addEventListener(ev, function (e) {
                        if (e.target && e.target.closest && (e.target.closest('[role="combobox"]') || e.target.closest('[role="listbox"]') || e.target.closest('[role="option"]'))) {
                            schedule();
                            setTimeout(schedule, 150);
                            setTimeout(schedule, 400);
                        }
                    }, true);
                } catch (e) { }
            });
        });
        log("Color observer attached for fields:", Object.keys(colorMaps));
    }

    return {
        onFormLoad: onFormLoad,
        // Exposed for debugging
        _clearCache: function () { _cache = {}; }
    };
})();
