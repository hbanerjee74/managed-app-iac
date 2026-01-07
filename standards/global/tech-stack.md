## Tech stack

Define your technical stack below. This serves as a reference for all team members and helps maintain consistency across the project.

### Framework & Runtime
- **Application Framework:** Express
- **Language/Runtime:** Node.js (backend), JavaScript (React) for frontend
- **Package Manager:** pnpm or npm

### Frontend
- **JavaScript Framework:** React with Vite
- **CSS Framework:** Tailwind CSS (via CDN)
- **UI Components:** Custom React components
- **State Management:** React hooks and context
- **Routing:** React Router
- **Markdown Rendering:** React Markdown for messages
- **Code Highlighting:** Syntax highlighting for code blocks
- **Dev Server Port:** Only launch on port `{frontend_port}`

### Database & Storage
- **Database:** SQLite
- **ORM/Query Builder:** Direct SQL or lightweight query helper
- **Caching:** In-memory (per Node.js process) if needed

### Testing & Quality
- **Test Framework:** Jest / Vitest for JS/TS
- **Linting/Formatting:** ESLint, Prettier

### Deployment & Infrastructure
- **Hosting:** Any Node-compatible host (e.g., Render, Fly.io, AWS, Azure)
- **CI/CD:** GitHub Actions

### Backend & Integration
- **Runtime / Framework:** Node.js with Express
- **API Integration:** Claude API for chat completions using Anthropic SDK
- **Streaming:** Server-Sent Events (SSE) for streaming responses to the frontend

### Communication
- **API Style:** RESTful endpoints
- **Real-time:** SSE for real-time message streaming between backend and frontend
- **Secrets:** API key available at `/tmp/api-key` (referenced in code, not read directly in tooling)

### Third-Party Services
- **LLM Provider:** Claude API via Anthropic SDK
- **Monitoring/Logging:** Application-level logging (to be detailed per environment)
