import { START, type BaseNode, type Workflow } from '@google/adk'

interface FlowNode {
  id: string
  type: string
  data: { label: string; kind: string }
  position: { x: number; y: number }
}

interface FlowEdge {
  id: string
  source: string
  target: string
  label?: string
}

export interface FlowGraph {
  name: string
  nodes: FlowNode[]
  edges: FlowEdge[]
}

const SPACING = { x: 240, y: 120 }
const KINDS = { start: 'start', code: 'code', judge: 'judge' }

const kindOf = (node: BaseNode) =>
  node === START ? KINDS.start : node.constructor.name === 'FunctionNode' ? KINDS.code : KINDS.judge

function depths(nodes: BaseNode[], edges: Array<[string, string]>): Map<string, number> {
  const depth = new Map(nodes.map((node) => [node.name, 0]))
  for (let pass = 0; pass < nodes.length; pass++) {
    for (const [from, to] of edges) {
      depth.set(to, Math.max(depth.get(to) ?? 0, (depth.get(from) ?? 0) + 1))
    }
  }
  return depth
}

export function graphOf(workflow: Workflow): FlowGraph {
  const { nodes = [], edges = [] } = workflow.graph ?? {}
  const pairs = edges.map((edge): [string, string] => [edge.fromNode.name, edge.toNode.name])
  const depth = depths(nodes, pairs)
  const seen = new Map<number, number>()
  return {
    name: workflow.name,
    nodes: nodes.map((node) => {
      const column = depth.get(node.name) ?? 0
      const row = seen.get(column) ?? 0
      seen.set(column, row + 1)
      return {
        id: node.name,
        type: kindOf(node),
        data: { label: node.name, kind: kindOf(node) },
        position: { x: column * SPACING.x, y: row * SPACING.y }
      }
    }),
    edges: edges.map((edge) => {
      const route = [edge.route].flat().filter((value) => value !== null && value !== undefined)
      return {
        id: `${edge.fromNode.name}->${edge.toNode.name}`,
        source: edge.fromNode.name,
        target: edge.toNode.name,
        ...(route.length > 0 ? { label: route.join(',') } : {})
      }
    })
  }
}
