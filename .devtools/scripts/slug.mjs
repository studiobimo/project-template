const camelBoundary = /([a-z0-9])([A-Z])/g
const separators = /[^a-zA-Z0-9]+/
const lower = (word) => word.toLowerCase()
const split = (name) => name.replace(camelBoundary, '$1 $2').split(separators)

export const words = (name) => split(name).filter(Boolean).map(lower)

export const kebab = (name) => words(name).join('-')
