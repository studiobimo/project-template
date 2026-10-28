// Managed by studiobimo/project-template (profile gcp); change it there.
//
// The server's part of the ESLint config, added after the shared rules by
// .devtools/vite/eslint.js.
import globals from 'globals'

export default [
  {
    // The server runs in Node: process, Buffer and the rest.
    files: ['server/**/*.ts'],
    languageOptions: { globals: globals.node }
  }
]
