import type { TestProjectInlineConfiguration } from 'vitest/config'

const projects: TestProjectInlineConfiguration[] = [
  {
    resolve: { tsconfigPaths: true },
    test: {
      name: 'server',
      environment: 'node',
      include: ['server/**/*.test.ts'],
      restoreMocks: true
    }
  }
]

export default projects
