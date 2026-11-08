import type { TestProjectInlineConfiguration } from 'vitest/config'

const projects: TestProjectInlineConfiguration[] = [
  {
    resolve: { tsconfigPaths: true },
    test: {
      name: 'worker',
      environment: 'node',
      include: ['worker/**/*.test.ts'],
      restoreMocks: true
    }
  }
]

export default projects
