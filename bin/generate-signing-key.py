#!/usr/bin/env python3

#: This module's copyright.
__copyright__ = '''
Copyright (c) 2000-2025, Board of Trustees of Leland Stanford Jr. University
'''.strip()

#: This module's license.
__license__ = __copyright__ + '\n\n' + '''
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
'''.strip()

#: This module's version
__version__ = '0.4.0-dev1'

from argparse import ArgumentParser, Namespace, SUPPRESS
from datetime import date
import getpass
import os
import shlex
import subprocess
import sys


# DN entries
_DN = {
    'organization': 'Organization',
    'unit': 'Organizational unit',
    'locality': 'City or locality',
    'state': 'State or province',
    'country': 'Two-letter ISO 3166 country code',
}

# DN defaults
_DN_LOCKSS = {
    'organization': 'Stanford University',
    'unit': 'LOCKSS Program',
    'locality': 'Stanford',
    'state': 'California',
    'country': 'US',
}


# Other constants
_keytool = os.path.join(os.environ['JAVA_HOME'], 'bin', 'keytool') if 'JAVA_HOME' in os.environ else 'keytool'
_ten_years_from_now_in_days = (date(date.today().year + 10, date.today().month, date.today().day) - date.today()).days


class GenerateSigningKey(object):

    @staticmethod
    def make_parser() -> ArgumentParser:
        parser = ArgumentParser(description='LOCKSS signing key generator')
        parser.add_argument('--copyright', '-C', action='store_true', help='show copyright and exit')
        parser.add_argument('--license', '-L', action='store_true', help='show license and exit')
        parser.add_argument('--version', '-V', action='version', version=__version__)
        # Group: Name
        group = parser.add_argument_group('Name')
        group.add_argument('--name', '-n', metavar='NAME', help='full name (default: interactive prompt)')
        group.add_argument('--alias', '-a', metavar='ALIAS', help='alias (default: interactive prompt)')
        # Group: Organization
        group = parser.add_argument_group('Organization')
        group.add_argument('--organization', '-o', metavar='ORG', help='organization (default: interactive prompt)')
        group.add_argument('--unit', '-u', metavar='UNIT', help='organizational unit (default: interactive prompt)')
        # Group: Location
        group = parser.add_argument_group('Location')
        group.add_argument('--locality', '-l', metavar='CITY', help='locality (default: interactive prompt)')
        group.add_argument('--state', '-s', metavar='STATE', help='state or province (default: interactive prompt)')
        group.add_argument('--country', '-c', metavar='CC', help='2-letter ISO 3166 country code (default: interactive prompt)')
        # Group: Import
        group = parser.add_argument_group('Import')
        group.add_argument('--import', '-i', dest='_import', action='store_true', default=None, help='import generated certificate into a keystore (default: interactive prompt)')
        group.add_argument('--no-import', dest='import_certificate', action='store_false', default=None, help='do not import generated certificate into a keystore (opposite of --import/-i)')
        group.add_argument('--keystore', '-k', metavar='FILE', help='keystore for import (default: interactive prompt)')
        # Group: Deprecated
        group = parser.add_argument_group('Miscellaneous')
        group.add_argument('--lockss', action='store_true', help=SUPPRESS) # Set -o, -u, -l, -s, -c for the LOCKSS Program
        group.add_argument('--verbose', '-v', action='store_true', help='output keytool commands')
        # Return parser
        return parser

    def __init__(self, parser: ArgumentParser, parsed: Namespace) -> None:
        super().__init__()
        # --help, --version are already taken care of by argparse
        # --copyright, --license
        if any([parsed.copyright, parsed.license]):
            if parsed.copyright:
                print(__copyright__)
            elif parsed.license:
                print(__license__)
            else:
                raise RuntimeError('internal error')
            sys.exit()
        # --verbose
        self.verbose = parsed.verbose
        # --lockss (undocumented)
        self.lockss = parsed.lockss
        if self.lockss and any(getattr(parsed, attr) for attr in _DN):
            parser.error('--lockss and --organization/--unit/--locality/--city/--state/--country are mutually exclusive')
        # --organization, --unit, --locality, --state, --country
        self.organization = parsed.organization
        self.unit = parsed.unit
        self.locality = parsed.locality
        self.state = parsed.state
        self.country = parsed.country
        # --name, --alias
        self.name = parsed.name
        self.alias = parsed.alias
        # --import/--no-import, --keystore
        self._import = parsed._import
        self.keystore = parsed.keystore
        # Passphrases
        self.key_passphrase = None
        self.keystore_passphrase = None

    def run(self) -> None:
        self._generate_key()
        self._export_certificate()
        self._display_certificate()
        self._import_certificate()

    def _display_certificate(self) -> None:
        cmd = [_keytool,
               '-printcert',
               '-file', f'{self.alias}.cer']
        self._run_command(cmd, output=True)

    def _export_certificate(self) -> None:
        cmd = [_keytool,
               '-exportcert',
               '-file', f'{self.alias}.cer',
               '-keystore', f'{self.alias}.keystore',
               '-alias', self.alias,
               '-storepass', self._get_key_passphrase()]
        self._run_command(cmd)

    def _generate_key(self) -> None:
        for attr in _DN:
            if self.lockss:
                setattr(self, attr, _DN_LOCKSS[attr])
            elif not getattr(self, attr):
                try:
                    entered = input(f'{_DN[attr]}: ')
                except (EOFError, KeyboardInterrupt):
                    sys.exit()
                setattr(self, attr, entered)
            else:
                pass # was set at the command line
        while not self.name:
            try:
                self.name = input('Full name (e.g. Firstname Lastname): ')
            except (EOFError, KeyboardInterrupt):
                sys.exit()
        while not self.alias:
            try:
                self.alias = input('Alias (e.g. flastname-org): ')
            except (EOFError, KeyboardInterrupt):
                sys.exit()
        cmd = [_keytool,
               '-genkeypair',
               '-keyalg', 'rsa',
               '-validity', str(_ten_years_from_now_in_days),
               '-alias', self.alias,
               '-dname', ','.join(f'{k}={v}' for k, v in (('CN', self.name),
                                                          ('O', self.organization),
                                                          ('OU', self.unit),
                                                          ('L', self.locality),
                                                          ('S', self.state),
                                                          ('C', self.country)) if v),
               '-keystore', f'{self.alias}.keystore',
               '-storepass', self._get_key_passphrase(),
               '-keypass', self._get_key_passphrase()]
        self._run_command(cmd)

    def _get_key_passphrase(self) -> str:
        while not self.key_passphrase:
            _p1 = getpass.getpass('Key passphrase: ')
            if not _p1:
                print('Key passphrase must not be empty')
                continue
            if len(_p1) < 6:
                print('Key passphrase must be at least 6 characters')
                continue
            _p2 = getpass.getpass('Confirm key passphrase: ')
            if _p1 != _p2:
                print('Key passphrases do not match')
                continue
            self.key_passphrase = _p1
        return self.key_passphrase

    def _get_keystore_passphrase(self) -> str:
        while not self.keystore_passphrase:
            _p3 = getpass.getpass('Keystore passphrase: ')
            if not _p3:
                print('Keystore passphrase must not be empty')
                continue
            if len(_p3) < 6:
                print('Keystore passphrase must be at least 6 characters')
                continue
            if not os.path.exists(self.keystore):
                _p4 = getpass.getpass('Confirm keystore passphrase: ')
                if _p3 != _p4:
                    print('Keystore passphrases do not match')
                    continue
            self.keystore_passphrase = _p3
        return self.keystore_passphrase

    def _import_certificate(self) -> None:
        if self._import is None:
            try:
                _r = input('Import certificate into a keystore? (Y/N) [N]: ')
            except (EOFError, KeyboardInterrupt):
                sys.exit()
            self._import = (_r or '').lower() == 'y'
        if not self._import:
            return
        while not self.keystore:
            try:
                self.keystore = input('Keystore: ')
            except (EOFError, KeyboardInterrupt):
                sys.exit()
        cmd = [_keytool,
               '-importcert',
               '-keystore', self.keystore,
               '-alias', self.alias,
               '-file', f'{self.alias}.cer',
               '-storepass', self._get_keystore_passphrase()]
        self._run_command(cmd, output=True)

    def _run_command(self, cmd: list[str], output: bool = False):
        if self.verbose:
            print(f'Executing: {shlex.join(self._sanitize(cmd))}')
            output = True
        if output:
            proc = subprocess.run(cmd, text=True, stdout=sys.stdout, stderr=sys.stdout)
        else:
            proc = subprocess.run(cmd, text=True, capture_output=True)
        if proc.returncode != 0:
            print(f'{cmd[0]} exited with {proc.returncode}')
            if proc.stdout:
                print(str(proc.stdout))
            if proc.stderr:
                print(str(proc.stderr))
            sys.exit(proc.returncode)

    def _sanitize(self, cmd: list[str]) -> list[str]:
        ret = cmd[0:1]
        for x in cmd[1:]:
            ret.append('<passphrase>' if ret[-1] in ('-storepass', '-keypass') else x)
        return ret


def main():
    """Main method."""
    parser = GenerateSigningKey.make_parser()
    gsc = GenerateSigningKey(parser, parser.parse_args())
    gsc.run()


if __name__ == '__main__':
    main()
