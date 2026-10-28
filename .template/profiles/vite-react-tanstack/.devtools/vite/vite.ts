// Managed by studiobimo/project-template (profile vite-react-tanstack); change it there.
//
// The shared half of vite.config.ts, with the hosting profile's half merged in from
// .devtools/host/vite.ts when there is one. The project's own file merges in what only it
// has:
//
//   export default mergeConfig(await app({ site }), { server: { port: 3000 } })
import { existsSync } from 'node:fs'

import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import { mergeConfig, type Plugin, type UserConfig } from 'vite'

/** The site's metadata, from src/config/site.ts: its one source of truth. */
export interface Site {
  name: string
  title: string
  description: string
  url: string
  ogImage: string
  themeColor: string
  locale: string
  [key: string]: string
}

export interface AppOptions {
  site: Site
  /** More vendor chunks, by name, on top of the shared ones. */
  vendors?: Record<string, RegExp>
}

// Large libraries that change rarely get their own long-cached chunk. Prefer a lazy route
// or lazy() to raising the bundle budget; add a vendor here only for a heavy dependency
// that every page loads.
const vendors: Record<string, RegExp> = {
  react: /[\\/]node_modules[\\/](react|react-dom|scheduler)[\\/]/,
  tanstack: /[\\/]node_modules[\\/]@tanstack[\\/]/,
  i18n: /[\\/]node_modules[\\/](i18next|react-i18next|i18next-browser-languagedetector)[\\/]/,
  radix: /[\\/]node_modules[\\/](radix-ui|@radix-ui[\\/][^\\/]+)[\\/]/
}

export async function app({ site, vendors: extra = {} }: AppOptions): Promise<UserConfig> {
  const shared: UserConfig = {
    plugins: [
      // Before react(): it rewrites the route files that react() then transforms.
      tanstackRouter({
        target: 'react',
        autoCodeSplitting: true,
        quoteStyle: 'single',
        semicolons: false
      }),
      react(),
      tailwindcss(),
      siteMetadata(site)
    ],
    resolve: { tsconfigPaths: true },
    build: {
      rolldownOptions: {
        output: {
          codeSplitting: {
            groups: Object.entries({ ...vendors, ...extra }).map(([name, test]) => ({
              name,
              test
            }))
          }
        }
      }
    }
  }
  const host = await hosting<() => UserConfig>('vite.ts')
  return host ? mergeConfig(shared, host()) : shared
}

/**
 * The default export of .devtools/host/<file>, which only a hosting profile writes. Node
 * loads it as it is rather than through Vite's bundler, so an app without a host never
 * has to resolve one.
 */
export async function hosting<T>(file: string): Promise<T | undefined> {
  const url = new URL(`../host/${file}`, import.meta.url)
  return existsSync(url) ? ((await import(url.href)) as { default: T }).default : undefined
}

const token = (key: string) => `%APP_${key.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toUpperCase()}%`

/**
 * Fills index.html's %APP_*% placeholders from the site metadata: `themeColor` is
 * %APP_THEME_COLOR%. A placeholder with no value fails the build rather than shipping.
 */
function siteMetadata(site: Site): Plugin {
  const values: Record<string, string> = { ...site, ogImage: new URL(site.ogImage, site.url).href }
  return {
    name: 'site-metadata',
    transformIndexHtml(html) {
      const out = Object.entries(values).reduce(
        (page, [key, value]) => page.replaceAll(token(key), value),
        html
      )
      const missing = out.match(/%APP_[A-Z0-9_]+%/g)
      if (missing) {
        throw new Error(`index.html: no site metadata for ${[...new Set(missing)].join(', ')}`)
      }
      return out
    }
  }
}
