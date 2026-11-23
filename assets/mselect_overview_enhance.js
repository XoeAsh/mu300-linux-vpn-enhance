'use strict';
'require baseclass';
'require rpc';
'require mu300.vpn as V';

/* One card for the active profile's manual groups. The RPC only exposes node names. */
var get = rpc.declare({ object: 'mu300mselect', method: 'get', expect: { '': {} } });
var setNode = rpc.declare({ object: 'mu300mselect', method: 'set', params: [ 'group', 'name' ], expect: { '': {} } });
var preferredGroup = null, previousProfile = null;

function unavailable(content, message) {
    content.push(E('div', { 'class': 'mvp-row' }, [
        E('label', { 'for': 'mvp-mihomo-node' }, [ _('Proxy node') ]),
        E('select', { 'class': 'cbi-input-select mvp-grow',
            'id': 'mvp-mihomo-node', 'disabled': true,
            'style': 'max-width:100%;opacity:.55;cursor:not-allowed' }, [
            E('option', { 'value': '' }, [ _('Selection unavailable') ])
        ])
    ]));
    content.push(V.note(message));
}

function card(d, refresh) {
    d = d || {};
    var content = [];
    if (d.profile !== previousProfile) {
        preferredGroup = null;
        previousProfile = d.profile;
    }

    if (d.ok !== 1) {
        unavailable(content, _('Node status is unavailable. Check the LuCI connection.'));
    } else if (!d.profile) {
        unavailable(content, _('Choose a Mihomo or sing-box profile to select a proxy node.'));
    } else if (d.type !== 'mihomo' && d.type !== 'sing-box') {
        unavailable(content, _('Node selection is available for Mihomo and sing-box profiles.'));
    } else if (d.reason === 'no-selector') {
        unavailable(content, _('This profile has no manual proxy groups.'));
    } else if (!d.online) {
        unavailable(content, _('Start or restart the VPN to connect to the node controller.'));
    } else if (!Array.isArray(d.groups) || !d.groups.length) {
        unavailable(content, _('This profile has no manual proxy groups.'));
    } else {
        var groups = d.groups.filter(function(g) {
            return g && typeof g.name === 'string' && Array.isArray(g.nodes);
        });
        if (!groups.length) {
            unavailable(content, _('This profile has no manual proxy groups.'));
        } else {
            if (!groups.some(function(g) { return g.name === preferredGroup; })) {
                var main = groups.filter(function(g) { return g.name !== 'GLOBAL'; });
                preferredGroup = (main[0] || groups[0]).name;
            }
            var groupSelector = E('select', {
                'class': 'cbi-input-select mvp-grow', 'id': 'mvp-mihomo-group',
                'style': 'max-width:100%'
            }, groups.map(function(g) { return E('option', { value: g.name }, [ g.name ]); }));
            groupSelector.value = preferredGroup;
            groupSelector.addEventListener('change', function() {
                preferredGroup = groupSelector.value;
                return refresh();
            });
            content.push(E('div', { 'class': 'mvp-row' }, [
                E('label', { 'for': 'mvp-mihomo-group' }, [ _('Proxy group') ]), groupSelector
            ]));
            var current = groups.filter(function(g) { return g.name === preferredGroup; })[0];
            var selected = String(current.selected || '');
            var nodes = current.nodes.filter(function(n) { return typeof n === 'string'; });
            var opts = nodes.map(function(n) { return E('option', { value: n }, [ n ]); });
            if (selected && nodes.indexOf(selected) < 0)
                opts.unshift(E('option', { value: '', disabled: true }, [ _('Current node: %s').format(selected) ]));
            if (!opts.length) opts.push(E('option', { value: '' }, [ _('No available nodes') ]));
            var selector = E('select', {
                'class': 'cbi-input-select mvp-grow', 'id': 'mvp-mihomo-node',
                'disabled': nodes.length ? null : true, 'style': 'max-width:100%'
            }, opts);
            selector.value = nodes.indexOf(selected) >= 0 ? selected : '';
            selector.addEventListener('change', function() {
                var choice = selector.value;
                if (!choice) return;
                return V.run(selector, function() { return setNode(current.name, choice); }, _('Proxy node switched'))
                    .then(function() { return refresh(); });
            });
            content.push(E('div', { 'class': 'mvp-row' }, [
                E('label', { 'for': 'mvp-mihomo-node' }, [ _('Proxy node') ]), selector
            ]));
            content.push(V.note(_('Node changes take effect immediately and are saved for this profile. Traffic rules must use the selected group.')));
        }
    }
    var reload = E('button', { 'class': 'mud-btn', type: 'button', 'id': 'mvp-mihomo-refresh' }, [ _('Refresh node status') ]);
    reload.addEventListener('click', function() { return refresh(); });
    content.push(E('div', { 'class': 'mvp-row' }, [ reload ]));
    return V.card(_('Proxy node selection'), content, 'mvp-mihomo-panel');
}

return baseclass.extend({
    load: function() { return L.resolveDefault(get(), { ok: 0 }); },
    card: card
});
