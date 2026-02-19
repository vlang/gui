# Locales

Gui provides a locale system for internationalization (i18n).
Features include number/date/currency formatting, UI string
translation, app-level translation keys, RTL layout mirroring,
and runtime language switching.

## Built-in Locales

Three locales are pre-registered at startup:

| ID      | Constant         | Direction |
|---------|------------------|-----------|
| `en-US` | `locale_en_us`   | LTR       |
| `de-DE` | `locale_de_de`   | LTR       |
| `ar-SA` | `locale_ar_sa`   | RTL       |

The default locale is `en-US`. Switch locales on a window:

```v ignore
window.set_locale(gui.locale_de_de)
```

## Locale Struct

`Locale` contains all locale-specific configuration:

```v ignore
pub struct Locale {
pub:
    id       string        = 'en-US'
    text_dir TextDirection = .ltr

    number   NumberFormat
    date     DateFormat
    currency CurrencyFormat

    // UI strings (str_ok, str_save, str_cancel, etc.)
    str_ok     string = 'OK'
    str_yes    string = 'Yes'
    // ... 25 more str_* fields

    // App-level translation keys
    translations map[string]string

    // Calendar arrays
    weekdays_short [7]string
    weekdays_med   [7]string
    weekdays_full  [7]string
    months_short   [12]string
    months_full    [12]string
}
```

All fields default to en-US values. Construct a locale inline
for simple cases:

```v ignore
my_locale := gui.Locale{
    id:     'fr-FR'
    str_ok: 'D accord'
    str_yes: 'Oui'
}
```

## JSON Bundles

For full locales, define a JSON bundle file:

```json
{
  "id": "ja-JP",
  "text_dir": "ltr",
  "number": {
    "decimal_sep": ".",
    "group_sep": ",",
    "group_sizes": [3],
    "minus_sign": "-",
    "plus_sign": "+"
  },
  "date": {
    "short_date": "YYYY/M/D",
    "long_date": "YYYY年M月D日",
    "month_year": "YYYY年M月",
    "first_day_of_week": 0,
    "use_24h": true
  },
  "currency": {
    "symbol": "¥",
    "code": "JPY",
    "position": "prefix",
    "decimals": 0
  },
  "strings": {
    "ok": "OK",
    "yes": "はい",
    "cancel": "キャンセル"
  },
  "weekdays_short": ["日","月","火","水","木","金","土"],
  "months_full": ["1月","2月","3月","4月","5月","6月",
                   "7月","8月","9月","10月","11月","12月"],
  "translations": {
    "greeting": "こんにちは"
  }
}
```

**Key rules:**
- Missing sections or keys fall back to en-US defaults.
- `"strings"` keys omit the `str_` prefix
  (JSON `"ok"` maps to `Locale.str_ok`).
- `"translations"` holds app-custom keys looked up via
  `locale_t()`.
- `"weekdays_*"` arrays must have exactly 7 elements or the
  defaults are used.
- `"months_*"` arrays must have exactly 12 elements or the
  defaults are used.
- `"text_dir"` accepts `"ltr"`, `"rtl"`, or `"auto"`.
- `"position"` (currency) accepts `"prefix"` or `"suffix"`.

Reference bundles are in `examples/locales/`.

## Loading Bundles

### From file

```v ignore
locale := gui.locale_load('locales/ja-JP.json')!
gui.locale_register(locale)
```

### From JSON string

```v ignore
locale := gui.locale_parse(json_content)!
gui.locale_register(locale)
```

### From embedded data

Use `$embed_file` to bake JSON into the binary — no disk
I/O at runtime:

```v ignore
const locale_data = [
    $embed_file('locales/de-DE.json'),
    $embed_file('locales/ja-JP.json'),
]!

// in on_init:
for data in locale_data {
    gui.locale_register(
        gui.locale_parse(data.to_string()) or { continue }
    )
}
```

### From directory

Load and register all `*.json` files in a directory:

```v ignore
gui.locale_load_dir('locales')!
```

## Locale Registry

All loaded locales are stored in a global registry keyed by
`id`. The three built-in locales are registered automatically.

```v ignore
// Register
gui.locale_register(my_locale)

// Retrieve
locale := gui.locale_get('ja-JP')!

// Switch by id on a window
window.set_locale_id('ja-JP')!
```

`locale_get` returns an error if the id is not registered.

## Translation Lookup

The `translations` map holds app-level string keys. Look up
the current locale's translation with `locale_t()`:

```v ignore
label := gui.locale_t('greeting') // "こんにちは" in ja-JP
```

If the key is not found, `locale_t` returns the key itself as
a fallback.

Combine with `locale_fmt()` for parameterized strings:

```v ignore
msg := gui.locale_fmt(
    gui.locale_t('welcome'),
    {'name': 'Alice'}
)
// template: "Welcome, {name}!" → "Welcome, Alice!"
```

## Runtime Language Switching

Switch the active locale on a window. This triggers a full
UI rebuild:

```v ignore
// By Locale struct
window.set_locale(gui.locale_de_de)

// By registry id
window.set_locale_id('ja-JP')!
```

All `str_*` fields, calendar arrays, number/date/currency
formats, text direction, and `locale_t()` lookups update
immediately.

## RTL Support

Set `text_dir: .rtl` (or `"text_dir": "rtl"` in JSON) for
right-to-left locales. The layout engine automatically
mirrors horizontal alignment, padding, and child order.

## Formatting Helpers

```v ignore
// Date formatting with locale-aware month names
gui.locale_format_date(time.now(), 'D. MMMM YYYY')

// Template string interpolation
gui.locale_fmt('Page {n} of {total}', {
    'n': '3', 'total': '10'
})
```

## API Summary

| Function | Description |
|----------|-------------|
| `locale_parse(json) !Locale` | Parse JSON string |
| `locale_load(path) !Locale` | Load JSON file |
| `locale_load_dir(dir) !` | Load + register directory |
| `locale_register(locale)` | Add to registry |
| `locale_get(id) !Locale` | Get from registry |
| `locale_t(key) string` | Translate key |
| `locale_fmt(tpl, params) string` | Interpolate template |
| `locale_format_date(t, fmt) string` | Format date |
| `window.set_locale(locale)` | Switch locale |
| `window.set_locale_id(id) !` | Switch by registry id |
