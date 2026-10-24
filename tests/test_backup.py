"""Integration tests using temporary config trees and local bare Git remotes."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'git-backup/rootfs/run.sh'


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.source = self.base / 'config'
        self.repo = self.base / 'repository'
        self.home = self.base / 'home'
        for path in (self.source, self.repo, self.home):
            path.mkdir()
        self.options = self.base / 'options.json'
        self.options.write_text('{}')
        self.env = dict(os.environ, HOME=str(self.home), GIT_CONFIG_NOSYSTEM='1',
                        GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'))
        subprocess.run(['git', 'init', '--bare', str(self.base / 'remote.git')],
                       check=True, capture_output=True, env=self.env)
        self.shell('load_configuration; setup_repository')

    def shell(self, code, check=True):
        prelude = '''
source "$1"
CONFIG_PATH="$2/options.json"
HA_CONFIG="$2/config"
REPO_DIR="$2/repository"
STATUS_FILE="$2/status.json"
REPOSITORY_URL="$2/remote.git"
BRANCH=main
COMMIT_USER_NAME=Test
COMMIT_USER_EMAIL=test@example.invalid
COMMIT_MESSAGE='Backup: {files}'
'''
        # load_configuration gets repository_url from this file too.
        options = json.loads(self.options.read_text())
        options['repository_url'] = str(self.base / 'remote.git')
        self.options.write_text(json.dumps(options))
        return subprocess.run(['bash', '-c', prelude + code, 'test', str(SCRIPT),
                               str(self.base)], env=self.env, check=check,
                              capture_output=True, text=True)

    def configure(self, includes=None, excludes=None):
        self.options.write_text(json.dumps({'include_patterns': includes or [],
                                           'exclude_patterns': excludes or []}))

    def write(self, name, content='example'):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def backup(self):
        return self.shell('do_backup test || exit 1')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args],
                                       env=self.env, text=True).strip()

    def test_home_fallback_and_existing_home(self):
        for value in (None, '', str(self.home)):
            env = dict(self.env)
            if value is None:
                env.pop('HOME', None)
            else:
                env['HOME'] = value
            result = subprocess.run(['bash', '-c', 'source "$1"; printf "%s" "$HOME"',
                                     'test', str(SCRIPT)], env=env, check=True,
                                    capture_output=True, text=True)
            self.assertEqual(result.stdout, value or '/data')
        self.assertEqual(self.shell('git config --global user.name').stdout.strip(), 'Home Assistant')

    def test_tracked_runtime_state_is_removed_once(self):
        self.write('zigbee2mqtt/state.json', 'old')
        self.write('configuration.yaml')
        self.backup()
        self.configure(['*.yaml', '*.json'], ['zigbee2mqtt/state.json'])
        self.backup()
        self.assertNotIn('zigbee2mqtt/state.json', self.git('ls-files'))
        self.assertTrue((self.source / 'zigbee2mqtt/state.json').exists())
        commit = self.git('rev-parse', 'HEAD')
        self.write('zigbee2mqtt/state.json', 'new')
        self.backup()
        self.assertEqual(commit, self.git('rev-parse', 'HEAD'))
        self.assertTrue((self.repo / '.git/HEAD').exists())

    def test_include_allowlist_and_explicit_exceptions(self):
        self.configure(['*.yaml', '*.json', '!.storage/core.config'],
                       ['.storage/*', 'zigbee2mqtt/state.json'])
        for name in ['configuration.yaml', 'nested/example.yaml', '.storage/core.config',
                     '.storage/auth.json', 'zigbee2mqtt/state.json', 'unwanted.txt']:
            self.write(name)
        self.backup()
        self.assertEqual(set(self.git('ls-files').splitlines()),
                         {'configuration.yaml', 'nested/example.yaml', '.storage/core.config'})

    def test_secrets_are_configurable_and_source_gitignore_is_preserved(self):
        self.configure(['*.yaml', '.gitignore', '!flows_cred.json'],
                       ['esphome/secrets.yaml', 'flows_cred.json'])
        for name in ['secrets.yaml', 'esphome/secrets.yaml', 'flows_cred.json']:
            self.write(name)
        self.write('.gitignore', 'secrets.yaml\nflows_cred.json\n')
        self.backup()
        self.assertIn('secrets.yaml', self.git('ls-files'))
        self.assertIn('flows_cred.json', self.git('ls-files'))
        self.assertNotIn('esphome/secrets.yaml', self.git('ls-files'))
        self.assertEqual((self.repo / '.gitignore').read_text(),
                         (self.source / '.gitignore').read_text())
        self.configure(['*.yaml', '.gitignore', '!esphome/secrets.yaml'], ['esphome/*'])
        self.backup()
        self.assertIn('esphome/secrets.yaml', self.git('ls-files'))

    def test_deletions_empty_filters_and_unusual_names(self):
        for name in ['nested/a space.yaml', 'nested/line\nbreak.txt', '-leading.txt']:
            self.write(name)
        self.backup()
        self.assertEqual(self.git('ls-files', '-z').count('\0'), 3)
        (self.source / '-leading.txt').unlink()
        self.backup()
        self.assertNotIn('-leading.txt', self.git('ls-files'))
        self.configure([], ['nested/'])
        self.backup()
        self.assertEqual(self.git('ls-files'), '')


    def test_default_filters_and_git_metadata(self):
        # Read defaults from the real add-on config without a YAML dependency.
        defaults = {}
        key = None
        for line in (ROOT / 'git-backup/config.yaml').read_text().splitlines():
            if line == 'schema:':
                break
            if line in ('  include_patterns:', '  exclude_patterns:'):
                key = line.strip().rstrip(':')
                defaults[key] = []
            elif key and line.startswith('    - '):
                defaults[key].append(json.loads(line[6:]))
            elif line.strip():
                key = None
        self.configure(defaults['include_patterns'], defaults['exclude_patterns'])
        for name in ['configuration.yaml', 'secrets.yaml', 'esphome/secrets.yaml',
                     'flows_cred.json', '.storage/lovelace.dashboard', '.storage/core.config',
                     '.storage/auth.json', 'home-assistant.log', 'backups/test.yaml',
                     'nested/.git/config', '.git/config']:
            self.write(name)
        original_git_config = (self.repo / '.git/config').read_bytes()
        self.backup()
        self.assertEqual(set(self.git('ls-files').splitlines()), {
            'configuration.yaml', 'secrets.yaml', 'esphome/secrets.yaml',
            'flows_cred.json', '.storage/lovelace.dashboard', '.storage/core.config'})
        self.assertTrue((self.repo / '.git/config').read_bytes().startswith(original_git_config))
        original_git_config = (self.repo / '.git/config').read_bytes()
        self.assertFalse((self.repo / 'nested/.git').exists())
        self.configure(['!*'], [])
        self.backup()
        self.assertEqual((self.repo / '.git/config').read_bytes(), original_git_config)

    def test_invalid_filters_abort_before_sync(self):
        self.write('configuration.yaml')
        self.backup()
        commit = self.git('rev-parse', 'HEAD')
        for invalid in [{'include_patterns': 'bad'}, {'exclude_patterns': [42]},
                        {'exclude_patterns': ['a\nb']}, {'include_patterns': ['a\0b']}]:
            self.options.write_text(json.dumps(invalid))
            result = self.shell('do_backup test || exit 1', check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(commit, self.git('rev-parse', 'HEAD'))

    def test_exception_under_excluded_parent_and_recursive_includes(self):
        self.configure(['*.yaml', '!private/', '!private/nested/',
                        '!private/nested/credentials.json', 'www/***'], ['private/***'])
        for name in ['private/nested/credentials.json', 'private/nested/other.yaml',
                     'www/assets/font.woff', 'configuration.yaml']:
            self.write(name)
        self.backup()
        self.assertEqual(set(self.git('ls-files').splitlines()), {
            'private/nested/credentials.json', 'www/assets/font.woff', 'configuration.yaml'})

    def test_failed_sync_never_stages_or_commits(self):
        self.write('configuration.yaml')
        self.backup()
        commit = self.git('rev-parse', 'HEAD')
        self.write('configuration.yaml', 'changed')
        result = self.shell('rsync() { return 23; }; do_backup test || exit 1', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commit, self.git('rev-parse', 'HEAD'))
        self.assertEqual(self.git('diff', '--cached', '--name-only'), '')


if __name__ == '__main__':
    unittest.main()
