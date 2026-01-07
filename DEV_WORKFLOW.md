# Developer Onboarding & Workflow

## Get Oriented into Linear
1. Watch the Linear overview video: <https://www.youtube.com/watch?v=9Q5BoiIFBiY> to understand how we structure teams, projects, and issue flows.
2. Walk through the Linear projects and issue templates the team uses so you can recognize `feature`, `bug`, and `meta` work as well as the custom fields that drive our automation.

## Get Oriented to Notion
1. PRDs define **what** we build—read the relevant PRD files in `docs/prd/` to understand goals, scope, and acceptance criteria.
2. RFCs explain **how** we build it—review the referenced RFCs under `docs/rfc/` to learn about architecture decisions, invariants, and guardrails.

## Prepare Your Environment
Assumes you have VS Code, a GitHub account, and access to the Accelerated Data (AD) organization.
1. Set up the Codex CLI following:
```
npm i -g @openai/codex
``` 


2. Install the Codex VS Code extension from the marketplace so prompts, orientation, and execution commands are available natively. 

**Codex – OpenAI’s coding agent**

https://marketplace.visualstudio.com/items?itemName=openai.chatgpt


3. Log in to Codex from the VS Code extension—this will launch a browser sign-in flow; authenticate with your Accelerate Data Google Workspace account.
The login is global - once you login from Extension, it also will be pickedup by CLI (the auth token sits in `~/.codex/auth.json`)

4. Configure MCP servers via the Codex CLI (it will be visible all the places):
   - Register the Linear MCP server 

   ```bash
   codex mcp add linear --url https://mcp.linear.app/mcp
   codex mcp login linear -c experimental_use_rmcp_client=true
    ```

   - Register the Notion MCP server and provide the Auth key 
```
   codex mcp add notion --env NOTION_TOKEN=<your-notion-token> -- npx -y @notionhq/notion-mcp-server
```

Update auth token manually in `~/.codex/config.toml `

```
[mcp_servers.notion.env]
NOTION_TOKEN = "ntn_130....."
```


## Working on an Issue
1. Ensure you have cloned/checked out the repository for the project you are working on.
2. Pull every relevant PRD and RFC for your issue—run `vd sync-docs` or use the Notion prompts to populate `docs/prd/` and `docs/rfc/`; these live in the repo so reviewers can see the source documents.
3. Run `other_prompts/codex_orientation_prompt.txt` with your assigned Linear issue number. The prompt generates a plan file under `.vibedata/plan-<ISSUE>.txt`; review it carefully before making changes.
4. Run `other_prompts/codex_execution_prompt.txt` using the plan file to implement the issue, update the Linear issue, and sync the corresponding PRD meta tracker automatically.

Keep this README handy as your quick reference whenever you join a sprint or start new work.
