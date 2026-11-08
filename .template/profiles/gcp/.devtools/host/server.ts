import { defineConfig } from 'vite'

export default defineConfig({
  resolve: { tsconfigPaths: true },
  ssr: { noExternal: true },
  build: {
    ssr: 'server/index.ts',
    outDir: 'dist/server',
    emptyOutDir: true,
    copyPublicDir: false,
    target: 'node24',
    sourcemap: true,
    rolldownOptions: { output: { entryFileNames: '[name].mjs' } }
  }
})
