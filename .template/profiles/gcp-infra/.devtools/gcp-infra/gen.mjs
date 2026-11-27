#!/usr/bin/env node
import { INFRA, infraFiles } from './scaffold.mjs'
import { projectOf, writeNew } from './write.mjs'

const { root, slug, deployEnvs } = projectOf(import.meta.url)
writeNew(root, infraFiles({ slug, deployEnvs }), INFRA.next)
