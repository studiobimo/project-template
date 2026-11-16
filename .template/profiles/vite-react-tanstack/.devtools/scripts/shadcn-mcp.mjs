#!/usr/bin/env node
import { spawn } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { appDirOf } from './app-dir.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')

const server = spawn('pnpm', ['exec', 'shadcn', 'mcp'], {
  cwd: join(root, appDirOf(root)),
  stdio: 'inherit'
})

server.on('exit', (code, signal) => {
  if (signal) process.kill(process.pid, signal)
  process.exit(code ?? 1)
})
