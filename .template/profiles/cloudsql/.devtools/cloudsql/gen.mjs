#!/usr/bin/env node
import { projectOf, writeNew } from '../gcp-infra/write.mjs'
import { CLOUDSQL, cloudsqlFiles } from './scaffold.mjs'

const { root } = projectOf(import.meta.url)
writeNew(root, cloudsqlFiles(), CLOUDSQL.next)
