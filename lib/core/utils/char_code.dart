/// The character a numeric HTML/XML entity stands for, or '' when [code] is
/// missing or not a Unicode code point. Canvas pages and Office files are not
/// ours: `&#99999999;` must not throw.
String charFromCode(int? code) => code == null || code < 0 || code > 0x10FFFF ? '' : String.fromCharCode(code);
