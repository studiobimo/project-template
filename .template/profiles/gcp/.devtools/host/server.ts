// Managed by studiobimo/project-template (profile gcp); change it there.
//
// The server's build, which `make -C .devtools build` runs beside the client's: server/index.ts
// and everything it imports, Hono included, bundled into dist/server/index.mjs. The image then
// needs Node and dist/, and nothing from node_modules.
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
