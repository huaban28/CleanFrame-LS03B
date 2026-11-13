"""Prepare source offline. Never connect, compile, sign, or change a TV."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--config', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
config = json.loads(Path(args.config).read_text(encoding='utf-8-sig'))
required = {'model', 'firmware', 'package_id', 'app_id', 'original_home', 'original_strings', 'original_autostart'}
if set(config) != required:
    raise SystemExit('Expected only the documented source-preparation fields.')
if config['model'] != 'QN75LS03BAFXZA' or config['firmware'] != 'T-PTMAKUC-1720.7':
    raise SystemExit('Exact model/firmware review required.')
package, app, original = config['package_id'], config['app_id'], config['original_home']
if not isinstance(package, str) or not re.fullmatch(r'[A-Za-z0-9]{10}', package):
    raise SystemExit('Invalid SDK package ID.')
if not isinstance(app, str) or not re.fullmatch(re.escape(package) + r'\.[A-Za-z0-9_-]{1,52}', app):
    raise SystemExit('Invalid application ID.')
if not isinstance(original, str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,160}', original) or original == app:
    raise SystemExit('A verified, nonempty, distinct original Home ID is required.')
keys = {'db/appfw/home_appid', 'db/appfw/startup_appid', 'db/appfw/booting_appid_backup', 'db/first_screen/type'}
strings = config['original_strings']
if not isinstance(strings, dict) or set(strings) != keys or any(v != original for v in strings.values()):
    raise SystemExit('This template requires the observed equal-string baseline; do not invent replacement values.')
if type(config['original_autostart']) is not int or config['original_autostart'] != 1:
    raise SystemExit('Original autostart must match the reviewed baseline of 1.')
output = Path(args.output).absolute()
root = Path(__file__).resolve().parents[3]
private_root = (root / '.local').resolve()
if not output.resolve().is_relative_to(private_root) or output.exists():
    raise SystemExit('Use a new output folder under the repository .local directory.')
output.mkdir(parents=True)
replacements = {'@@LAUNCHER_APP_ID@@': app, '@@LAUNCHER_PACKAGE_ID@@': package, '@@ORIGINAL_HOME@@': original}
for source in Path(__file__).parent.glob('*.cs.in'):
    text = source.read_text()
    for token, value in replacements.items():
        text = text.replace(token, value)
    if '@@' in text:
        raise SystemExit('Unresolved source placeholder.')
    (output / source.name.removesuffix('.in')).write_text(text)
(output / 'FrameQuery.csproj').write_bytes((Path(__file__).parent / 'FrameQuery.csproj.template').read_bytes())
(output / 'NuGet.Config').write_bytes((Path(__file__).parent / 'NuGet.Config').read_bytes())
print('Prepared source only. Review guards and preserve your baseline before any device operation.')
