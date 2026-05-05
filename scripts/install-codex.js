#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const { createInstallState, writeInstallState } = require('./lib/install-state');

const REPO_ROOT = path.join(__dirname, '..');
const REPO_VERSION = fs.readFileSync(path.join(REPO_ROOT, 'VERSION'), 'utf8').trim();

const BASELINE_PACK = Object.freeze({
  id: 'baseline',
  description: 'Codex project-local baseline for daily engineering work.',
  paths: [
    '.codex',
    '.codex-plugin',
    '.mcp.json',
    '.agents/plugins/marketplace.json',
    '.agents/skills/agent-introspection-debugging',
    '.agents/skills/agent-sort',
    '.agents/skills/api-design',
    '.agents/skills/backend-patterns',
    '.agents/skills/coding-standards',
    '.agents/skills/documentation-lookup',
    '.agents/skills/e2e-testing',
    '.agents/skills/eval-harness',
    '.agents/skills/security-review',
    '.agents/skills/strategic-compact',
    '.agents/skills/tdd-workflow',
    '.agents/skills/verification-loop',
    'AGENTS.md',
    'agents/build-error-resolver.md',
    'agents/code-architect.md',
    'agents/code-reviewer.md',
    'agents/doc-updater.md',
    'agents/e2e-runner.md',
    'agents/planner.md',
    'agents/security-reviewer.md',
    'agents/tdd-guide.md',
    'commands/build-fix.md',
    'commands/code-review.md',
    'commands/docs.md',
    'commands/e2e.md',
    'commands/plan.md',
    'commands/refactor-clean.md',
    'commands/setup-pm.md',
    'commands/tdd.md',
    'commands/test-coverage.md',
    'commands/update-docs.md',
    'commands/verify.md',
    'hooks',
    'rules/common',
    'scripts/hooks',
    'scripts/lib',
    'skills/agent-introspection-debugging',
    'skills/agent-sort',
    'skills/api-design',
    'skills/backend-patterns',
    'skills/coding-standards',
    'skills/documentation-lookup',
    'skills/e2e-testing',
    'skills/eval-harness',
    'skills/security-review',
    'skills/strategic-compact',
    'skills/tdd-workflow',
    'skills/verification-loop',
  ],
});

const LANGUAGE_PACKS = Object.freeze({
  go: {
    aliases: ['go', 'golang'],
    description: 'Go rules, skills, agents, and command shims.',
    paths: [
      'agents/go-build-resolver.md',
      'agents/go-reviewer.md',
      'commands/go-build.md',
      'commands/go-review.md',
      'commands/go-test.md',
      'rules/golang',
      'skills/golang-patterns',
      'skills/golang-testing',
    ],
  },
  typescript: {
    aliases: ['ts', 'tsx', 'typescript', 'js', 'jsx', 'javascript', 'node'],
    description: 'TypeScript, web, and modern JS application-engineering surfaces.',
    paths: [
      'agents/typescript-reviewer.md',
      'rules/typescript',
      'rules/web',
      'skills/bun-runtime',
      'skills/frontend-design',
      'skills/frontend-patterns',
      'skills/mcp-server-patterns',
    ],
  },
});

const LANGUAGE_ALIAS_MAP = Object.freeze(
  Object.fromEntries(
    Object.entries(LANGUAGE_PACKS).flatMap(([canonical, pack]) => (
      pack.aliases.map(alias => [alias, canonical])
    ))
  )
);

function getHelpText() {
  return `
Usage: install_codex.sh [--dry-run] [--json] <language> [<language> ...]

Examples:
  ./install_codex.sh go ts
  ./install_codex.sh --dry-run typescript

Supported language aliases:
  go: ${LANGUAGE_PACKS.go.aliases.join(', ')}
  typescript: ${LANGUAGE_PACKS.typescript.aliases.join(', ')}
`;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const parsed = {
    dryRun: false,
    json: false,
    help: false,
    languages: [],
  };

  for (const arg of args) {
    if (arg === '--dry-run') {
      parsed.dryRun = true;
      continue;
    }

    if (arg === '--json') {
      parsed.json = true;
      continue;
    }

    if (arg === '--help' || arg === '-h') {
      parsed.help = true;
      continue;
    }

    if (arg.startsWith('--')) {
      throw new Error(`Unknown argument: ${arg}`);
    }

    parsed.languages.push(arg);
  }

  return parsed;
}

function normalizeLanguages(languages) {
  const canonical = [];
  const unknown = [];

  for (const language of languages) {
    const normalized = String(language || '').trim().toLowerCase();
    if (!normalized) {
      continue;
    }

    const resolved = LANGUAGE_ALIAS_MAP[normalized];
    if (!resolved) {
      unknown.push(language);
      continue;
    }

    if (!canonical.includes(resolved)) {
      canonical.push(resolved);
    }
  }

  if (unknown.length > 0) {
    throw new Error(`Unsupported language aliases: ${unknown.join(', ')}`);
  }

  if (canonical.length === 0) {
    throw new Error('At least one language alias is required');
  }

  return canonical;
}

function listFilesRecursively(rootPath, relativePrefix = '') {
  const entries = fs.readdirSync(rootPath, { withFileTypes: true })
    .sort((left, right) => left.name.localeCompare(right.name));
  const files = [];

  for (const entry of entries) {
    const nextRelative = relativePrefix
      ? path.join(relativePrefix, entry.name)
      : entry.name;
    const absolutePath = path.join(rootPath, entry.name);

    if (entry.isDirectory()) {
      files.push(...listFilesRecursively(absolutePath, nextRelative));
      continue;
    }

    if (entry.isFile()) {
      files.push(nextRelative);
    }
  }

  return files;
}

function buildOperations(projectRoot, selectedLanguages) {
  const allPaths = [
    ...BASELINE_PACK.paths,
    ...selectedLanguages.flatMap(language => LANGUAGE_PACKS[language].paths),
  ];
  const seenFiles = new Set();
  const operations = [];

  for (const sourceRelativePath of allPaths) {
    const sourcePath = path.join(REPO_ROOT, sourceRelativePath);
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`Configured Codex install path is missing: ${sourceRelativePath}`);
    }

    const stat = fs.statSync(sourcePath);
    const files = stat.isDirectory()
      ? listFilesRecursively(sourcePath, sourceRelativePath)
      : [sourceRelativePath];

    for (const relativeFile of files) {
      const normalizedFile = relativeFile.replace(/\\/g, '/');
      if (seenFiles.has(normalizedFile)) {
        continue;
      }

      seenFiles.add(normalizedFile);
      operations.push({
        kind: 'copy-path',
        moduleId: inferModuleId(normalizedFile),
        sourceRelativePath: normalizedFile,
        sourcePath: path.join(REPO_ROOT, normalizedFile),
        destinationPath: path.join(projectRoot, normalizedFile),
        strategy: 'preserve-relative-path',
        ownership: 'managed',
        scaffoldOnly: true,
      });
    }
  }

  return operations.sort((left, right) => (
    left.sourceRelativePath.localeCompare(right.sourceRelativePath)
  ));
}

function inferModuleId(sourceRelativePath) {
  if (sourceRelativePath.startsWith('rules/')) {
    return 'codex-rules';
  }
  if (sourceRelativePath.startsWith('skills/') || sourceRelativePath.startsWith('.agents/skills/')) {
    return 'codex-skills';
  }
  if (sourceRelativePath.startsWith('agents/') || sourceRelativePath === 'AGENTS.md') {
    return 'codex-agents';
  }
  if (sourceRelativePath.startsWith('commands/')) {
    return 'codex-commands';
  }
  if (
    sourceRelativePath.startsWith('hooks/')
    || sourceRelativePath.startsWith('scripts/hooks/')
    || sourceRelativePath.startsWith('scripts/lib/')
  ) {
    return 'codex-hooks-runtime';
  }
  if (
    sourceRelativePath.startsWith('.codex')
    || sourceRelativePath.startsWith('.codex-plugin/')
    || sourceRelativePath === '.mcp.json'
    || sourceRelativePath.startsWith('.agents/plugins/')
  ) {
    return 'codex-platform';
  }

  return 'codex-misc';
}

function printPlan(plan) {
  console.log('Codex project install plan:\n');
  console.log(`Target root: ${plan.projectRoot}`);
  console.log(`Install-state: ${plan.installStatePath}`);
  console.log(`Baseline: ${BASELINE_PACK.id}`);
  console.log(`Languages: ${plan.selectedLanguages.join(', ')}`);
  console.log(`Operations: ${plan.operations.length}`);
  console.log('\nSelected packs:');
  console.log(`- ${BASELINE_PACK.id}: ${BASELINE_PACK.description}`);
  for (const language of plan.selectedLanguages) {
    console.log(`- ${language}: ${LANGUAGE_PACKS[language].description}`);
  }
  console.log('\nPlanned file operations:');
  for (const operation of plan.operations) {
    console.log(`- ${operation.sourceRelativePath} -> ${operation.destinationPath}`);
  }
}

function applyOperations(operations) {
  for (const operation of operations) {
    fs.mkdirSync(path.dirname(operation.destinationPath), { recursive: true });
    fs.copyFileSync(operation.sourcePath, operation.destinationPath);
  }
}

function createState(projectRoot, installStatePath, selectedLanguages, operations) {
  return createInstallState({
    adapter: {
      id: 'codex-project-installer',
      target: 'codex-project',
      kind: 'project',
    },
    targetRoot: projectRoot,
    installStatePath,
    request: {
      profile: 'codex-project',
      modules: ['baseline', ...selectedLanguages.map(language => `lang:${language}`)],
      includeComponents: selectedLanguages.map(language => `lang:${language}`),
      excludeComponents: [],
      legacyLanguages: selectedLanguages,
      legacyMode: false,
    },
    resolution: {
      selectedModules: ['baseline', ...selectedLanguages.map(language => `lang:${language}`)],
      skippedModules: [],
    },
    source: {
      repoVersion: REPO_VERSION,
      repoCommit: null,
      manifestVersion: 1,
    },
    operations,
  });
}

function main() {
  try {
    const parsed = parseArgs(process.argv);
    if (parsed.help) {
      process.stdout.write(getHelpText());
      return;
    }

    const projectRoot = process.cwd();
    const selectedLanguages = normalizeLanguages(parsed.languages);
    const installStatePath = path.join(projectRoot, '.codex', 'ecc-install-state.json');
    const operations = buildOperations(projectRoot, selectedLanguages);
    const state = createState(projectRoot, installStatePath, selectedLanguages, operations);
    const plan = {
      projectRoot,
      installStatePath,
      selectedLanguages,
      operations,
      state,
    };

    if (parsed.dryRun) {
      if (parsed.json) {
        process.stdout.write(`${JSON.stringify({ dryRun: true, plan }, null, 2)}\n`);
      } else {
        printPlan(plan);
      }
      return;
    }

    applyOperations(operations);
    writeInstallState(installStatePath, state);

    if (parsed.json) {
      process.stdout.write(`${JSON.stringify({ dryRun: false, result: plan }, null, 2)}\n`);
    } else {
      printPlan(plan);
      console.log(`\nDone. Install-state written to ${installStatePath}`);
    }
  } catch (error) {
    process.stderr.write(`Error: ${error.message}\n${getHelpText()}`);
    process.exit(1);
  }
}

main();
