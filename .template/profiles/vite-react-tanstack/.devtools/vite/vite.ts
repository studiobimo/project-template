import { existsSync } from 'node:fs'

import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import { mergeConfig, type Plugin, type UserConfig } from 'vite'

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
  vendors?: Record<string, RegExp>
}

const vendors: Record<string, RegExp> = {
  react: /[\\/]node_modules[\\/](react|react-dom|scheduler)[\\/]/,
  tanstack: /[\\/]node_modules[\\/]@tanstack[\\/]/,
  i18n: /[\\/]node_modules[\\/](i18next|react-i18next|i18next-browser-languagedetector)[\\/]/,
  radix: /[\\/]node_modules[\\/](radix-ui|@radix-ui[\\/][^\\/]+)[\\/]/
}

export async function app({ site, vendors: extra = {} }: AppOptions): Promise<UserConfig> {
  const shared: UserConfig = {
    plugins: [
      tanstackRouter({
        target: 'react',
        autoCodeSplitting: true,
        quoteStyle: 'single',
        semicolons: false,
        routeTreeFileHeader: []
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

export async function hosting<T>(file: string): Promise<T | undefined> {
  const url = new URL(`../host/${file}`, import.meta.url)
  return existsSync(url) ? ((await import(url.href)) as { default: T }).default : undefined
}

const token = (key: string) => `%APP_${key.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toUpperCase()}%`

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
