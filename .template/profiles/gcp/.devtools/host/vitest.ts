// Managed by studiobimo/project-template (profile gcp); change it there.
//
// The server's test project, added to the React one by .devtools/vite/vitest.ts. Its tests
// call the Hono app directly, app.request(path, init), in Node, as Cloud Run runs it.
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
