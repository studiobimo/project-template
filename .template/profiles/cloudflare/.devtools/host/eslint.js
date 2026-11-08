import { globalIgnores } from 'eslint/config'
import globals from 'globals'

export default [
  globalIgnores(['.wrangler', 'worker/worker-configuration.d.ts']),
  {
    files: ['worker/**/*.ts'],
    languageOptions: { globals: globals.serviceworker }
  }
]
