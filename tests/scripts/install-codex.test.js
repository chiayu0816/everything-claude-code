/**
 * Tests for install_codex.sh project-local Codex installs.
 */

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const SCRIPT = path.join(__dirname, '..', '..', 'install_codex.sh');

function createTempDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

function cleanup(dirPath) {
  fs.rmSync(dirPath, { recursive: true, force: true });
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function run(args = [], options = {}) {
  try {
    const stdout = execFileSync('bash', [SCRIPT, ...args], {
      cwd: options.cwd,
      env: {
        ...process.env,
        HOME: options.homeDir || process.env.HOME,
      },
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 15000,
    });

    return { code: 0, stdout, stderr: '' };
  } catch (error) {
    return {
      code: error.status || 1,
      stdout: error.stdout || '',
      stderr: error.stderr || '',
    };
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`  \u2713 ${name}`);
    return true;
  } catch (error) {
    console.log(`  \u2717 ${name}`);
    console.log(`    Error: ${error.message}`);
    return false;
  }
}

function runTests() {
  console.log('\n=== Testing install_codex.sh ===\n');

  let passed = 0;
  let failed = 0;

  if (test('supports dry-run with go and ts aliases', () => {
    const projectDir = createTempDir('install-codex-project-');

    try {
      const result = run(['--dry-run', 'go', 'ts'], { cwd: projectDir });
      assert.strictEqual(result.code, 0, result.stderr);
      assert.ok(result.stdout.includes('Codex project install plan'));
      assert.ok(result.stdout.includes('Languages: go, typescript'));
      assert.ok(result.stdout.includes('.codex-plugin/plugin.json'));
      assert.ok(result.stdout.includes('rules/golang/testing.md'));
      assert.ok(result.stdout.includes('rules/typescript/testing.md'));
      assert.ok(!fs.existsSync(path.join(projectDir, '.codex', 'ecc-install-state.json')));
    } finally {
      cleanup(projectDir);
    }
  })) passed++; else failed++;

  if (test('installs baseline plus selected go/typescript surfaces into the project root', () => {
    const projectDir = createTempDir('install-codex-project-');

    try {
      const result = run(['go', 'ts'], { cwd: projectDir });
      assert.strictEqual(result.code, 0, result.stderr);

      assert.ok(fs.existsSync(path.join(projectDir, '.codex', 'config.toml')));
      assert.ok(fs.existsSync(path.join(projectDir, '.codex-plugin', 'plugin.json')));
      assert.ok(fs.existsSync(path.join(projectDir, '.mcp.json')));
      assert.ok(fs.existsSync(path.join(projectDir, 'AGENTS.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'agents', 'go-reviewer.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'agents', 'typescript-reviewer.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'commands', 'go-test.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'commands', 'plan.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'rules', 'common', 'coding-style.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'rules', 'golang', 'testing.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'rules', 'typescript', 'testing.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'rules', 'web', 'testing.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'skills', 'golang-patterns', 'SKILL.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'skills', 'frontend-patterns', 'SKILL.md')));
      assert.ok(fs.existsSync(path.join(projectDir, 'scripts', 'hooks', 'session-start.js')));
      assert.ok(fs.existsSync(path.join(projectDir, 'scripts', 'lib', 'install-state.js')));

      const state = readJson(path.join(projectDir, '.codex', 'ecc-install-state.json'));
      assert.strictEqual(state.target.id, 'codex-project-installer');
      assert.deepStrictEqual(state.request.legacyLanguages, ['go', 'typescript']);
      assert.deepStrictEqual(state.request.modules, ['baseline', 'lang:go', 'lang:typescript']);
      assert.ok(
        state.operations.some(operation => operation.sourceRelativePath === 'skills/golang-patterns/SKILL.md')
      );
    } finally {
      cleanup(projectDir);
    }
  })) passed++; else failed++;

  if (test('rejects unsupported language aliases', () => {
    const projectDir = createTempDir('install-codex-project-');

    try {
      const result = run(['elixir'], { cwd: projectDir });
      assert.strictEqual(result.code, 1);
      assert.ok(result.stderr.includes('Unsupported language aliases: elixir'));
    } finally {
      cleanup(projectDir);
    }
  })) passed++; else failed++;

  console.log(`\nResults: Passed: ${passed}, Failed: ${failed}`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests();
