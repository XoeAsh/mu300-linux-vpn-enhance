'use strict';
'require baseclass';
'require rpc';
'require mu300.vpn as V';

/* One persistent card on Overview; works with any active Mihomo YAML containing
 * a type: select strategy group. Server-side permissions and values are checked
 * against Mihomo's Unix-socket API. No proxy credentials are exposed. */
var get = rpc.declare({ object: 'mu300mselect', method: 'get', expect: { '': {} } });
var setNode = rpc.declare({ object: 'mu300mselect', method: 'set', params: [ 'group', 'name' ], expect: { '': {} } });
var preferredGroup = null, previousProfile = null;

function unavailable(content, message) {
    content.push(E('div', { 'class': 'mvp-row' }, [
        E('label', { 'for': 'mvp-mihomo-node' }, [ '代理节点' ]),
        E('select', { 'class': 'cbi-input-select mvp-grow',
            'id': 'mvp-mihomo-node', 'disabled': true,
            'style': 'max-width:100%;opacity:.55;cursor:not-allowed' }, [
            E('option', { 'value': '' }, [ '暂不可选择' ])
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
        unavailable(content, '暂时无法获取节点控制状态，请检查 LuCI 管理接口。');
    } else if (!d.profile) {
        unavailable(content, '尚未选中任何 VPN 配置。请先在“当前配置文件”中选择一个 Mihomo YAML。');
    } else if (d.type !== 'mihomo') {
        unavailable(content, '当前启用的是 ' + String(d.type || '非 Mihomo') + ' 配置。节点切换仅支持 Mihomo YAML；切换到 Mihomo 配置后将自动识别策略组。');
    } else if (!d.online) {
        unavailable(content, '已选中 Mihomo YAML，但 VPN 尚未运行或节点控制接口未连接。卡片始终显示；启动 VPN 后即可选择节点。');
    } else if (!Array.isArray(d.groups) || !d.groups.length) {
        unavailable(content, '当前 Mihomo YAML 没有可手动切换的 select 策略组。url-test、fallback 等自动策略组由 Mihomo 管理，无法在这里手动选择。');
    } else {
        var groups = d.groups.filter(function(g) {
            return g && typeof g.name === 'string' && Array.isArray(g.nodes);
        });
        if (!groups.length) {
            unavailable(content, '当前 YAML 没有可识别的手动选择策略组。');
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
                E('label', { 'for': 'mvp-mihomo-group' }, [ '代理策略组' ]), groupSelector
            ]));
            var current = groups.filter(function(g) { return g.name === preferredGroup; })[0];
            var selected = String(current.selected || '');
            var nodes = current.nodes.filter(function(n) { return typeof n === 'string'; });
            var opts = nodes.map(function(n) { return E('option', { value: n }, [ n ]); });
            if (selected && nodes.indexOf(selected) < 0)
                opts.unshift(E('option', { value: '', disabled: true }, [ '当前值：' + selected ]));
            if (!opts.length) opts.push(E('option', { value: '' }, [ '无可选节点' ]));
            var selector = E('select', {
                'class': 'cbi-input-select mvp-grow', 'id': 'mvp-mihomo-node',
                'disabled': nodes.length ? null : true, 'style': 'max-width:100%'
            }, opts);
            selector.value = nodes.indexOf(selected) >= 0 ? selected : '';
            selector.addEventListener('change', function() {
                var choice = selector.value;
                if (!choice) return;
                return V.run(selector, function() { return setNode(current.name, choice); }, '节点切换成功')
                    .then(function() { return refresh(); });
            });
            content.push(E('div', { 'class': 'mvp-row' }, [
                E('label', { 'for': 'mvp-mihomo-node' }, [ '代理节点' ]), selector
            ]));
            content.push(V.note('自动识别当前 Mihomo 配置中的手动选择策略组。切换节点立即生效，无需重启 VPN；不同配置的选择会分别保存。请注意：流量规则必须实际使用该策略组。'));
        }
    }
    var reload = E('button', { 'class': 'mud-btn', type: 'button', 'id': 'mvp-mihomo-refresh' }, [ '刷新节点状态' ]);
    reload.addEventListener('click', function() { return refresh(); });
    content.push(E('div', { 'class': 'mvp-row' }, [ reload ]));
    return V.card('Mihomo 节点选择', content, 'mvp-mihomo-panel');
}

return baseclass.extend({
    load: function() { return L.resolveDefault(get(), { ok: 0 }); },
    card: card
});
