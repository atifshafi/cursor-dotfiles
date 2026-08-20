const { spawn } = require('child_process');
const readline = require('readline');

const NODE_BIN = '/Users/ashafi/.nvm/versions/node/v22.17.1/bin/node';
const ENGRAM_CLI = '/Users/ashafi/.nvm/versions/node/v22.17.1/lib/node_modules/engram-sdk/dist/cli.js';

const child = spawn(
  NODE_BIN,
  [ENGRAM_CLI, 'mcp'],
  {
    env: { ...process.env },
    stdio: ['pipe', 'pipe', 'pipe']
  }
);

process.stdin.pipe(child.stdin);

const rl = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
rl.on('line', (line) => {
  if (line.startsWith('{')) {
    process.stdout.write(line + '\n');
  }
});

child.stderr.on('data', (data) => {
  process.stderr.write(data);
});

child.on('error', (err) => {
  process.stderr.write(`engram spawn error: ${err.message}\n`);
  process.exit(1);
});

child.on('exit', (code) => process.exit(code || 0));
process.on('SIGTERM', () => child.kill());
process.on('SIGINT', () => child.kill());
