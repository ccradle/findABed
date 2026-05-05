/*
 * /contact.js — info-email-contact §6.1 shared static-site fetcher
 * (info-email-contact OpenSpec change, 2026-05).
 *
 * Loaded once per in-scope HTML page via:
 *   <script defer src="/contact.js"></script>
 * placed near the closing </body>.
 *
 * Behavior:
 *   1. Read document.documentElement.lang to pick EN or ES copy from the
 *      embedded i18n dict (§7.15 + Q1 — no per-page Spanish HTML
 *      duplication; future Spanish-localized pages opt in by setting
 *      lang="es" on the <html> element).
 *   2. Hydrate every <span class="footer-contact-leadin"> with the
 *      lang-aware lead-in copy.
 *   3. Fetch /api/v1/public/contact-info once.
 *   4. On success with a non-empty platform email: for every
 *      <a class="contact-email" hidden>, set href="mailto:<email>",
 *      set textContent to the email, remove the hidden attribute.
 *      The aria-live="polite" already on the element causes screen
 *      readers to announce the value when it appears.
 *   5. On failure (network, non-2xx, empty email): swap the placeholder
 *      to the GH-issues fallback link with lang-aware text. Single
 *      console.warn for ops; no error spam.
 *
 * Resilience: this script runs at <body> end with `defer` AND wraps
 * everything in DOMContentLoaded as belt-and-suspenders. No build-time
 * step. No bundler. Browsers that block JavaScript (Dr. Whitfield's
 * locked-down hospital Chrome scenario) fall back to the per-page
 * <noscript> link in the HTML — the placeholder element stays hidden
 * and the noscript-fallback renders.
 */
(function () {
    'use strict';

    /**
     * Lang-aware copy dict. EN + ES strings authored 2026-05-04 during
     * info-email-contact §6.1. ES strings AI-synthetic-reviewed only;
     * logged in `reference_es_json_ai_synthetic_reviewed.md` for
     * future native-reviewer pass alongside the v0.55+v0.56 keys.
     */
    var I18N = {
        en: {
            leadIn: 'Contact the FABT project team:',
            ghFallback: 'Contact via GitHub Issues'
        },
        es: {
            leadIn: 'Contacte al equipo del proyecto FABT:',
            ghFallback: 'Contacte por GitHub Issues'
        }
    };

    var GH_ISSUES_URL = 'https://github.com/ccradle/finding-a-bed-tonight/issues';
    var CONTACT_INFO_ENDPOINT = '/api/v1/public/contact-info';

    function pickLang() {
        // Default to English on absent / unrecognized values; only flip
        // to ES when the page explicitly sets lang="es" on <html>.
        var raw = (document.documentElement.lang || 'en').toLowerCase();
        return raw.indexOf('es') === 0 ? 'es' : 'en';
    }

    function hydrateLeadIns(text) {
        var nodes = document.querySelectorAll('span.footer-contact-leadin');
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].textContent = text;
        }
    }

    function applyToPlaceholders(transform) {
        var nodes = document.querySelectorAll('a.contact-email[hidden]');
        for (var i = 0; i < nodes.length; i++) {
            transform(nodes[i]);
        }
    }

    function renderEmail(node, email) {
        node.setAttribute('href', 'mailto:' + email);
        node.textContent = email;
        node.removeAttribute('hidden');
    }

    function renderFallback(node, fallbackText) {
        node.setAttribute('href', GH_ISSUES_URL);
        node.textContent = fallbackText;
        node.removeAttribute('hidden');
    }

    function init() {
        var lang = pickLang();
        var copy = I18N[lang];

        // §6.1 — i18n the lead-in copy first so the leadin appears even
        // when the placeholder is still hidden during the fetch window.
        hydrateLeadIns(copy.leadIn);

        // §6.1 — single fetch; failure modes (network, non-2xx, empty
        // email) all collapse to the same GH-issues fallback rendering.
        fetch(CONTACT_INFO_ENDPOINT, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
            credentials: 'omit'
        })
            .then(function (response) {
                if (!response.ok) {
                    throw new Error('contact-info responded ' + response.status);
                }
                return response.json();
            })
            .then(function (body) {
                // Anonymous response shape: {"platform":{"email":"..."},"tenant":null}
                // Tenant block may be elided by Jackson — anonymous-fetched
                // pages never see a tenant block anyway, so reading
                // platform.email is the only path here.
                var email = body && body.platform && body.platform.email;
                if (typeof email !== 'string' || email.length === 0) {
                    throw new Error('contact-info returned empty platform email');
                }
                applyToPlaceholders(function (node) { renderEmail(node, email); });
            })
            .catch(function (err) {
                // Single warn. The fallback rendering is the user-facing
                // behavior; this log is for ops.
                if (typeof console !== 'undefined' && console.warn) {
                    console.warn('[contact.js] falling back to GH issues link:', err && err.message);
                }
                applyToPlaceholders(function (node) { renderFallback(node, copy.ghFallback); });
            });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
