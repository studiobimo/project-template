import globals from 'globals'

export default [
  {
    files: ['server/**/*.ts'],
    languageOptions: { globals: globals.node }
  }
]
