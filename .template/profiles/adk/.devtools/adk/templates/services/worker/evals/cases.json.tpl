[
  {
    "name": "documentation only change",
    "event": {
      "source": "github",
      "deliveryId": "eval-1",
      "repository": "acme/app",
      "pullRequest": 1,
      "action": "opened",
      "title": "docs: fix a typo in the README",
      "changedFiles": ["README.md"]
    },
    "expect": { "verdict": "approve" }
  },
  {
    "name": "change to the authentication code",
    "event": {
      "source": "github",
      "deliveryId": "eval-2",
      "repository": "acme/app",
      "pullRequest": 2,
      "action": "opened",
      "title": "feat: replace the session store",
      "body": "Moves sessions to a new store and changes how tokens are validated.",
      "changedFiles": ["src/auth/session.ts", "src/auth/tokens.ts"]
    },
    "expect": { "verdict": "review" }
  }
]
