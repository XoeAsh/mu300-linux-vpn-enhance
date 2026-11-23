'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const [root, subscriptions] = process.argv.slice(2);
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const card = read('assets/mselect_overview_enhance.js');
const views = card + fs.readFileSync(subscriptions, 'utf8');
const selector = read('assets/mu300-mihomo-selector');
const rpc = read('assets/mu300mselect');
const messages = new Set([
    ...Array.from(views.matchAll(/_\('([^']+)'\)/g), (match) => match[1]),
    ...Array.from(selector.matchAll(/\|\| error '([^']+)'/g), (match) => match[1]),
    ...Array.from(rpc.matchAll(/"error":"([^"]+)"/g), (match) => match[1])
]);

const render = new Function('baseclass', 'rpc', 'V', 'E', '_', card);
for (const [language, expected] of [
    ['en', 'Mihomo node selection'],
    ['zh-cn', 'Mihomo 节点选择'],
    ['tr', 'Mihomo düğüm seçimi']
]) {
    const catalog = new Map();
    if (language !== 'en') {
        for (const [, id, text] of read(`i18n/${language}.po`).matchAll(/^msgid (".+")\nmsgstr (".+")$/gm)) {
            const source = JSON.parse(id);
            const translation = JSON.parse(text);
            assert.equal((translation.match(/%s/g) || []).length, (source.match(/%s/g) || []).length);
            catalog.set(source, translation);
        }
        assert.deepEqual(new Set(catalog.keys()), messages, language);
    }
    const translate = (text) => catalog.get(text) || text;
    const view = render(
        { extend: (module) => module },
        { declare: () => {} },
        { note: (text) => text, card: (title) => title },
        () => ({ addEventListener() {} }),
        translate
    );
    assert.equal(view.card({ ok: 0 }, () => {}), expected);
}
