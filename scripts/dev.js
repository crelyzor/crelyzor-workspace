#!/usr/bin/env node
import { networkInterfaces } from 'os';
import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';

const expose = process.argv.includes('--expose');
const root   = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/* ── Detect network IP ──────────────────────────────────────────────────── */
function getLocalIP() {
  for (const iface of Object.values(networkInterfaces())) {
    for (const net of iface) {
      if (net.family === 'IPv4' && !net.internal) return net.address;
    }
  }
  return 'localhost';
}

const host = expose ? getLocalIP() : 'localhost';

/* ── Write .env.local files ─────────────────────────────────────────────── */
function write(path, content) {
  writeFileSync(resolve(root, path), content.trimStart());
}

// crelyzor-frontend
write('crelyzor-frontend/.env.local', `
VITE_API_BASE_URL=http://${host}:4000/api/v1
VITE_CARDS_PUBLIC_URL=http://${host}:5174
`);

// crelyzor-public
write('crelyzor-public/.env.local', `
NEXT_PUBLIC_API_BASE_URL=http://${host}:4000/api/v1
NEXT_PUBLIC_BASE_URL=http://${host}:5174
NEXT_PUBLIC_CALENDAR_URL=http://${host}:5173
`);

// crelyzor-backend — write a .env.local that overrides localhost vars
write('crelyzor-backend/.env.local', `
BASE_URL=http://${host}:4000/api/v1
CARDS_PUBLIC_URL=http://${host}:5174
GOOGLE_LOGIN_REDIRECT_URI=http://${host}:4000/api/v1/auth/google/login/callback
ALLOWED_ORIGINS=http://${host}:5173,http://${host}:5174,http://localhost:5173,http://localhost:5174
`);

/* ── Print summary ──────────────────────────────────────────────────────── */
console.log('\x1b[2m');
if (expose) {
  console.log('  Exposing on network:');
  console.log(`    Dashboard  →  http://${host}:5173`);
  console.log(`    Public     →  http://${host}:5174`);
  console.log(`    API        →  http://${host}:4000`);
} else {
  console.log('  Running locally:');
  console.log(`    Dashboard  →  http://localhost:5173`);
  console.log(`    Public     →  http://localhost:5174`);
  console.log(`    API        →  http://localhost:4000`);
}
console.log('\x1b[0m');

/* ── Spawn services ─────────────────────────────────────────────────────── */
const colorMap = { cyan: '36', magenta: '35', green: '32', yellow: '33' };

const services = [
  { name: 'API',    color: 'cyan',    cwd: 'crelyzor-backend',  cmd: 'pnpm dev' },
  { name: 'WORKER', color: 'magenta', cwd: 'crelyzor-backend',  cmd: 'pnpm dev:worker' },
  { name: 'DASH',   color: 'green',   cwd: 'crelyzor-frontend', cmd: 'pnpm dev' },
  { name: 'PUBLIC', color: 'yellow',  cwd: 'crelyzor-public',   cmd: 'pnpm dev' },
];

const procs = services.map(({ name, color, cwd, cmd }) => {
  const [bin, ...args] = cmd.split(' ');
  const proc = spawn(bin, args, {
    cwd: resolve(root, cwd),
    env: process.env,
    shell: true,
  });
  const prefix = `\x1b[${colorMap[color]}m[${name}]\x1b[0m`;
  proc.stdout.on('data', (d) => process.stdout.write(`${prefix} ${d}`));
  proc.stderr.on('data', (d) => process.stderr.write(`${prefix} ${d}`));
  proc.on('exit', (code) => {
    if (code !== 0) {
      console.error(`${prefix} exited with code ${code}`);
      procs.forEach((p) => p.kill());
      process.exit(code ?? 1);
    }
  });
  return proc;
});

const shutdown = () => { procs.forEach((p) => p.kill()); process.exit(0); };
process.on('SIGINT',  shutdown);
process.on('SIGTERM', shutdown);
