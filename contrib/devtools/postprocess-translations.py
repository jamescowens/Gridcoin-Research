#!/usr/bin/env python3
# Copyright (c) 2014 Wladimir J. van der Laan
# Copyright (c) 2026 The Gridcoin developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or https://opensource.org/licenses/mit-license.php.
'''
Post-process translation files pulled from Transifex.

Derived from bitcoin-core/bitcoin-maintainer-tools update-translations.py.
Adapted for Gridcoin: removed Autotools/ts_files.cmake output, auto-detects
lconvert binary, configurable via command-line arguments.

Operations:
  - Convert XLIFF (.xlf) files to Qt TS (.ts) format
  - Remove invalid control characters
  - Remove translations with mismatched format specifiers
  - Remove translations containing cryptocurrency addresses
  - Remove location tags (reduces diff noise)
  - Drop languages with too few translated messages
  - Clean up temporary files
'''
import argparse
import io
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

# Regexp to check for Bitcoin/Gridcoin addresses.
# Bitcoin: 1/3 (P2PKH/P2SH), bc1 (bech32)
# Gridcoin mainnet: S (base58 prefix 62), testnet: m/n (prefix 111)
ADDRESS_REGEXP = re.compile('([13Smn]|bc1)[a-zA-Z0-9]{30,}')
# Original content file suffix
ORIGINAL_SUFFIX = '.orig'
# Native Qt translation file (TS) format
FORMAT_TS = '.ts'
# XLIFF file format
FORMAT_XLIFF = '.xlf'
# Control characters that must be stripped
FIX_RE = re.compile(b'[\x00-\x09\x0b\x0c\x0e-\x1f]')


def find_lconvert():
    '''Auto-detect the Qt lconvert binary.'''
    override = os.getenv('LCONVERT', '')
    if override:
        return override
    for candidate in ('lconvert-qt6', 'lconvert6', 'lconvert'):
        if shutil.which(candidate):
            return candidate
    print('ERROR: lconvert not found. Install qt6-l10n-tools.', file=sys.stderr)
    sys.exit(1)


def all_ts_files(locale_dir, source_lang, file_format=FORMAT_TS,
                 suffix='', include_source=False):
    '''Yield (filename, filepath) for all translation files.'''
    for filename in sorted(os.listdir(locale_dir)):
        if not filename.endswith(file_format + suffix):
            continue
        if not include_source and filename == source_lang + file_format + suffix:
            continue
        if suffix:
            filename = filename[:-len(suffix)]
        filepath = os.path.join(locale_dir, filename)
        yield (filename, filepath)


def convert_xlf_to_ts(locale_dir, source_lang):
    '''Convert any .xlf files to .ts format. Returns True if conversions were done.'''
    xliff_files = list(all_ts_files(locale_dir, source_lang,
                                    file_format=FORMAT_XLIFF))
    if not xliff_files:
        return False

    lconvert = find_lconvert()
    for (_, name) in xliff_files:
        outname = name.replace(FORMAT_XLIFF, FORMAT_TS)
        print('Converting %s to %s...' % (name, outname))
        # Transifex delivers files with .xlf extension but in Qt TS format
        # (they start with <!DOCTYPE TS>). Force input format detection to
        # handle this correctly.
        with open(name, 'rb') as f:
            header = f.read(256)
        if b'<!DOCTYPE TS' in header:
            subprocess.check_call([lconvert, '-if', 'ts',
                                   '-o', outname, '-i', name])
        else:
            subprocess.check_call([lconvert, '-o', outname, '-i', name])
        os.remove(name)
    return True


def find_format_specifiers(s):
    '''Find all format specifiers in a string.'''
    pos = 0
    specifiers = []
    while True:
        percent = s.find('%', pos)
        if percent < 0:
            break
        specifiers.append(s[percent + 1])
        pos = percent + 2
    return specifiers


def split_format_specifiers(specifiers):
    '''Split format specifiers between numeric (Qt) and others (strprintf).'''
    numeric = []
    other = []
    for s in specifiers:
        if s in {'1', '2', '3', '4', '5', '6', '7', '8', '9'}:
            numeric.append(s)
        else:
            other.append(s)

    # If both numeric format specifiers and "others" are used, assume Qt
    # formatting where only numeric formats are replaced. This means
    # "(percentage: %1%)" is valid without escaping.
    if numeric:
        other = []

    return set(numeric), other


def sanitize_string(s):
    '''Sanitize string for printing.'''
    return s.replace('\n', ' ')


def check_format_specifiers(source, translation, errors, numerus):
    '''Check that format specifiers match between source and translation.'''
    source_f = split_format_specifiers(find_format_specifiers(source))
    assert not (source_f[0] and source_f[1]), \
        'Source contains both Qt and strprintf specifiers: %s' % source
    try:
        translation_f = split_format_specifiers(
            find_format_specifiers(translation))
    except IndexError:
        errors.append("Parse error in translation for '%s': '%s'"
                       % (sanitize_string(source), sanitize_string(translation)))
        return False
    else:
        if source_f != translation_f:
            if (numerus and source_f == (set(), ['n'])
                    and translation_f == (set(), [])
                    and translation.find('%') == -1):
                return True
            errors.append("Mismatch between '%s' and '%s'"
                           % (sanitize_string(source),
                              sanitize_string(translation)))
            return False
    return True


def contains_address(text, errors):
    '''Check if text contains a cryptocurrency address.'''
    if text is not None and ADDRESS_REGEXP.search(text) is not None:
        errors.append('Translation "%s" contains a cryptocurrency address. '
                       'This will be removed.' % text)
        return True
    return False


def remove_invalid_characters(s):
    '''Remove invalid control characters from translation data.'''
    return FIX_RE.sub(b'', s)


def postprocess_message(filename, message, xliff_compatible_mode):
    '''Validate and clean up a single translation message. Returns True to keep.'''
    translation_node = message.find('translation')
    if not xliff_compatible_mode and translation_node.get('type') == 'unfinished':
        return False

    numerus = message.get('numerus') == 'yes'
    source = message.find('source').text

    if numerus:
        translations = [i.text for i in translation_node.findall('numerusform')]
    else:
        if translation_node.text is None or translation_node.text == source:
            return False
        translations = [translation_node.text]

    for translation in translations:
        if translation is None:
            continue
        errors = []
        valid = (check_format_specifiers(source, translation, errors, numerus)
                 and not contains_address(translation, errors))

        for error in errors:
            print('%s: %s' % (filename, error))

        if not valid:
            return False

    # Remove location tags (reduces diff noise)
    for location in message.findall('location'):
        message.remove(location)

    return True


def postprocess_translations(locale_dir, source_lang, min_messages,
                              xliff_compatible_mode):
    '''Post-process all translation files: sanitize, validate, drop empty.'''
    print('Checking and postprocessing...')

    for (filename, filepath) in all_ts_files(locale_dir, source_lang):
        os.rename(filepath, filepath + ORIGINAL_SUFFIX)

    for (filename, filepath) in all_ts_files(locale_dir, source_lang,
                                              suffix=ORIGINAL_SUFFIX):
        parser = ET.XMLParser(encoding='utf-8')
        with open(filepath + ORIGINAL_SUFFIX, 'rb') as f:
            data = f.read()
        data = remove_invalid_characters(data)
        tree = ET.parse(io.BytesIO(data), parser=parser)

        root = tree.getroot()
        for context in root.findall('context'):
            for message in context.findall('message'):
                if not postprocess_message(filename, message,
                                            xliff_compatible_mode):
                    context.remove(message)

            if not context.findall('message'):
                root.remove(context)

        # Drop languages with too few translations
        num_nonnumerus_messages = 0
        for context in root.findall('context'):
            for message in context.findall('message'):
                if message.get('numerus') != 'yes':
                    num_nonnumerus_messages += 1

        if num_nonnumerus_messages < min_messages:
            print('Removing %s, as it contains only %i non-numerus messages'
                  % (filepath, num_nonnumerus_messages))
            continue

        tree.write(filepath, encoding='utf-8')


def remove_orig_files(locale_dir, source_lang):
    '''Remove temporary .orig files.'''
    for (_, name) in all_ts_files(locale_dir, source_lang,
                                   suffix=ORIGINAL_SUFFIX):
        orig = name + ORIGINAL_SUFFIX
        if os.path.exists(orig):
            os.remove(orig)


def main():
    parser = argparse.ArgumentParser(
        description='Post-process translation files pulled from Transifex.')
    parser.add_argument('--locale-dir', default='src/qt/locale',
                        help='Directory containing .ts/.xlf files '
                             '(default: src/qt/locale)')
    parser.add_argument('--source-lang', default='bitcoin_en',
                        help='Source language file basename without extension '
                             '(default: bitcoin_en)')
    parser.add_argument('--min-messages', type=int, default=10,
                        help='Minimum non-numerus messages to keep a language '
                             '(default: 10)')
    args = parser.parse_args()

    xliff_mode = convert_xlf_to_ts(args.locale_dir, args.source_lang)
    postprocess_translations(args.locale_dir, args.source_lang,
                              args.min_messages, xliff_mode)
    remove_orig_files(args.locale_dir, args.source_lang)
    print('Post-processing complete.')


if __name__ == '__main__':
    main()
