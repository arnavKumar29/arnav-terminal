arnavterminal.md# Making AI Tool Executions Transparent & Terminal-Integrated

## Architecture Overview

```
User Approves Tool → Show Command → Inject into PTY → Capture Output → Feed back to AI
```

---

## Step 1: Update the Tool Approval UI (`AiToolApproval.tsx`)

```tsx
// AiToolApproval.tsx

import React, { useState } from "react";
import { Terminal, Eye, Play, FolderPlus, FileEdit } from "lucide-react";

// Map any tool call to its human-readable shell equivalent
function toolToShellCommand(toolName: string, toolArgs: Record<string, any>): string {
  switch (toolName) {
    case "create_directory":
      return `mkdir -p "${toolArgs.path}"`;

    case "write_file":
      return `cat > "${toolArgs.path}" << 'EOF'\n${toolArgs.content}\nEOF`;

    case "delete_file":
      return `rm -f "${toolArgs.path}"`;

    case "move_file":
      return `mv "${toolArgs.source}" "${toolArgs.destination}"`;

    case "bash_run":
      return toolArgs.command; // already a shell command

    case "read_file":
      return `cat "${toolArgs.path}"`;

    default:
      return `# ${toolName}(${JSON.stringify(toolArgs, null, 2)})`;
  }
}

// Color coding per tool type
function getToolColor(toolName: string) {
  const map: Record<string, string> = {
    bash_run:          "border-yellow-500 bg-yellow-500/10",
    create_directory:  "border-blue-500  bg-blue-500/10",
    write_file:        "border-green-500 bg-green-500/10",
    delete_file:       "border-red-500   bg-red-500/10",
    move_file:         "border-purple-500 bg-purple-500/10",
    read_file:         "border-cyan-500  bg-cyan-500/10",
  };
  return map[toolName] ?? "border-gray-500 bg-gray-500/10";
}

interface AiToolApprovalProps {
  toolName: string;
  toolArgs: Record<string, any>;
  onApprove: (runInTerminal: boolean) => void;
  onReject: () => void;
}

export function AiToolApproval({
  toolName,
  toolArgs,
  onApprove,
  onReject,
}: AiToolApprovalProps) {
  const [showRaw, setShowRaw] = useState(false);
  const shellCommand = toolToShellCommand(toolName, toolArgs);
  const colorClass   = getToolColor(toolName);

  return (
    <div className={`rounded-xl border-2 p-4 my-2 ${colorClass}`}>
      
      {/* Header */}
      <div className="flex items-center gap-2 mb-3">
        <FolderPlus size={16} />
        <span className="font-bold text-sm uppercase tracking-wider">
          AI wants to: {toolName.replace(/_/g, " ")}
        </span>
        <button
          onClick={() => setShowRaw(!showRaw)}
          className="ml-auto text-xs opacity-60 hover:opacity-100 flex items-center gap-1"
        >
          <Eye size={12} />
          {showRaw ? "Show Shell" : "Show Raw JSON"}
        </button>
      </div>

      {/* Command Preview */}
      <div className="bg-black/50 rounded-lg p-3 mb-3 font-mono text-sm">
        {showRaw ? (
          // Raw JSON args
          <pre className="text-gray-300 whitespace-pre-wrap">
            {JSON.stringify(toolArgs, null, 2)}
          </pre>
        ) : (
          // Shell equivalent - THIS is what makes it transparent
          <div>
            <span className="text-green-400 select-none">$ </span>
            <span className="text-white">{shellCommand}</span>
          </div>
        )}
      </div>

      {/* Action Buttons */}
      <div className="flex gap-2">

        {/* Option A: Approve (background, AI reads output) */}
        <button
          onClick={() => onApprove(false)}
          className="flex-1 bg-green-600 hover:bg-green-500 
                     text-white rounded-lg py-2 px-3 text-sm 
                     font-semibold flex items-center justify-center gap-2"
        >
          <Play size={14} />
          Approve (Background)
        </button>

        {/* Option B: Run in YOUR terminal visibly */}
        <button
          onClick={() => onApprove(true)}
          className="flex-1 bg-blue-600 hover:bg-blue-500 
                     text-white rounded-lg py-2 px-3 text-sm 
                     font-semibold flex items-center justify-center gap-2"
        >
          <Terminal size={14} />
          Run in Terminal
        </button>

        {/* Reject */}
        <button
          onClick={onReject}
          className="bg-red-600 hover:bg-red-500 
                     text-white rounded-lg py-2 px-4 text-sm font-semibold"
        >
          ✕
        </button>

      </div>
    </div>
  );
}
```

---

## Step 2: The PTY Injection & Output Capture (`ptyManager.ts`)

```typescript
// ptyManager.ts
// This is the CORE - injects commands into terminal AND captures output

import * as pty from "node-pty";
import { EventEmitter } from "events";

interface PtySession {
  pty:        pty.IPty;
  emitter:    EventEmitter;
  outputBuf:  string;
}

// Store active PTY sessions by ID
const sessions = new Map<string, PtySession>();

// ─── Create or Get PTY ────────────────────────────────────────────────────────
export function createPtySession(id: string, cwd: string): PtySession {
  const shell = process.platform === "win32" ? "powershell.exe" : "bash";

  const ptyProcess = pty.spawn(shell, [], {
    name: "xterm-256color",
    cols: 120,
    rows: 40,
    cwd,
    env: process.env as Record<string, string>,
  });

  const session: PtySession = {
    pty:       ptyProcess,
    emitter:   new EventEmitter(),
    outputBuf: "",
  };

  // Accumulate output so AI can read it back
  ptyProcess.onData((data) => {
    session.outputBuf += data;
    session.emitter.emit("data", data); // stream to frontend
  });

  sessions.set(id, session);
  return session;
}

// ─── Run in Background (AI reads output) ─────────────────────────────────────
export function runInBackground(
  command: string,
  cwd: string
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve) => {
    const { execFile } = require("child_process");
    
    execFile(
      "bash",
      ["-c", command],
      { cwd, env: process.env },
      (error: any, stdout: string, stderr: string) => {
        resolve({
          stdout,
          stderr,
          exitCode: error?.code ?? 0,
        });
      }
    );
  });
}

// ─── Inject into Active PTY (User sees it) ───────────────────────────────────
export function injectIntoActivePty(
  sessionId: string,
  command: string,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const session = sessions.get(sessionId);
    if (!session) {
      reject(new Error(`No PTY session: ${sessionId}`));
      return;
    }

    // Clear the output buffer before running
    session.outputBuf = "";

    // Write command + Enter key → user sees it typed in terminal
    session.pty.write(command + "\r");

    // Wait for a short idle period to capture output
    // (real impl: wait for shell prompt to return)
    let idleTimer: NodeJS.Timeout;
    
    const onData = () => {
      clearTimeout(idleTimer);
      // If no new data for 500ms, assume command is done
      idleTimer = setTimeout(() => {
        session.emitter.off("data", onData);
        resolve(session.outputBuf);
      }, 500);
    };

    session.emitter.on("data", onData);

    // Safety timeout after 30s
    setTimeout(() => {
      session.emitter.off("data", onData);
      resolve(session.outputBuf);
    }, 30_000);
  });
}

// ─── Better: Wait for Prompt (more reliable than idle timer) ─────────────────
export function injectAndWaitForPrompt(
  sessionId: string,
  command: string,
  promptPattern = /\$\s*$/m  // matches "$ " at end = shell is ready
): Promise<string> {
  return new Promise((resolve, reject) => {
    const session = sessions.get(sessionId);
    if (!session) return reject(new Error("No session"));

    session.outputBuf = "";
    let collected = "";

    const onData = (data: string) => {
      collected += data;
      // When we see the prompt again, command has finished
      if (promptPattern.test(collected)) {
        session.emitter.off("data", onData);
        resolve(collected);
      }
    };

    session.emitter.on("data", onData);
    session.pty.write(command + "\r");
  });
}
```

---

## Step 3: The Tool Executor (`toolExecutor.ts`)

```typescript
// toolExecutor.ts
// Decides HOW to run a tool based on user's button choice

import { runInBackground, injectAndWaitForPrompt } from "./ptyManager";
import * as fs from "fs/promises";
import * as path from "path";

export interface ToolResult {
  success:  boolean;
  output:   string;
  error?:   string;
  visibleToAI: boolean; // did AI get to read the output?
}

export async function executeTool(
  toolName:       string,
  toolArgs:       Record<string, any>,
  runInTerminal:  boolean,    // true = user's terminal, false = background
  activeSessionId: string,
  cwd:            string,
): Promise<ToolResult> {

  // ── File system tools - always run in background (no terminal needed) ──────
  if (toolName === "create_directory") {
    await fs.mkdir(toolArgs.path, { recursive: true });
    return {
      success:     true,
      output:      `Created: ${toolArgs.path}`,
      visibleToAI: true,
    };
  }

  if (toolName === "write_file") {
    await fs.mkdir(path.dirname(toolArgs.path), { recursive: true });
    await fs.writeFile(toolArgs.path, toolArgs.content, "utf8");
    return {
      success:     true,
      output:      `Written: ${toolArgs.path}`,
      visibleToAI: true,
    };
  }

  if (toolName === "delete_file") {
    await fs.rm(toolArgs.path, { force: true, recursive: true });
    return {
      success:     true,
      output:      `Deleted: ${toolArgs.path}`,
      visibleToAI: true,
    };
  }

  if (toolName === "read_file") {
    const content = await fs.readFile(toolArgs.path, "utf8");
    return {
      success:     true,
      output:      content,
      visibleToAI: true,
    };
  }

  // ── bash_run - this is where the choice matters ───────────────────────────
  if (toolName === "bash_run") {
    const command = toolArgs.command as string;

    if (runInTerminal) {
      // User clicked "Run in Terminal" → inject into PTY
      // AI gets output back via the captured buffer
      const output = await injectAndWaitForPrompt(activeSessionId, command);
      return {
        success:     true,
        output,
        visibleToAI: true, // We captured it! Best of both worlds
      };

    } else {
      // User clicked "Approve (Background)" → silent execution
      const result = await runInBackground(command, cwd);
      return {
        success:     result.exitCode === 0,
        output:      result.stdout,
        error:       result.stderr || undefined,
        visibleToAI: true,
      };
    }
  }

  return {
    success:     false,
    output:      "",
    error:       `Unknown tool: ${toolName}`,
    visibleToAI: false,
  };
}
```

---

## Step 4: Hook it all together in the AI Message Handler

```typescript
// aiMessageHandler.ts
// Where the AI response comes in and tools get dispatched

import { executeTool, ToolResult } from "./toolExecutor";
import { sendToAI } from "./aiClient"; // your existing AI client

interface PendingTool {
  toolName:  string;
  toolArgs:  Record<string, any>;
  resolve:   (runInTerminal: boolean) => void;
  reject:    () => void;
}

// Queue of tools waiting for user approval
const pendingApprovals = new Map<string, PendingTool>();

// Called by frontend when user clicks Approve or Run in Terminal
export function userApprovedTool(toolId: string, runInTerminal: boolean) {
  const pending = pendingApprovals.get(toolId);
  if (pending) {
    pending.resolve(runInTerminal);
    pendingApprovals.delete(toolId);
  }
}

// Called by frontend when user clicks ✕
export function userRejectedTool(toolId: string) {
  const pending = pendingApprovals.get(toolId);
  if (pending) {
    pending.reject();
    pendingApprovals.delete(toolId);
  }
}

// Main loop: ask AI, handle tools, loop back
export async function runAiWithTools(
  userMessage:     string,
  activeSessionId: string,
  cwd:             string,
  sendToFrontend:  (event: string, data: any) => void, // e.g. socket.emit
) {
  let messages = [{ role: "user", content: userMessage }];

  while (true) {
    // Ask the AI
    const response = await sendToAI(messages);

    // Stream text to the user as it comes
    if (response.text) {
      sendToFrontend("ai:text", { text: response.text });
    }

    // If no tool calls, we're done
    if (!response.toolCalls || response.toolCalls.length === 0) {
      break;
    }

    // Process each tool call
    const toolResults = [];

    for (const toolCall of response.toolCalls) {
      const toolId = toolCall.id;

      // 1. Show the approval card in the frontend
      sendToFrontend("ai:tool_pending", {
        toolId,
        toolName: toolCall.name,
        toolArgs: toolCall.args,
      });

      // 2. Wait for user to click Approve or Reject
      const runInTerminal = await new Promise<boolean>((resolve, reject) => {
        pendingApprovals.set(toolId, {
          toolName: toolCall.name,
          toolArgs: toolCall.args,
          resolve,
          reject,
        });
      });

      // 3. Execute the tool
      sendToFrontend("ai:tool_running", { toolId });

      const result: ToolResult = await executeTool(
        toolCall.name,
        toolCall.args,
        runInTerminal,
        activeSessionId,
        cwd,
      );

      // 4. Show result in UI
      sendToFrontend("ai:tool_result", {
        toolId,
        success: result.success,
        output:  result.output,
        error:   result.error,
      });

      toolResults.push({
        toolId,
        result: result.output,
        error:  result.error,
      });
    }

    // 5. Feed results back to AI so it can continue
    messages = [
      ...messages,
      { role: "assistant", content: response.toolCalls },
      { role: "tool",      content: toolResults },
    ];

    // Loop back → AI sees results and decides next step
  }
}
```

---

## Step 5: Frontend Event Listener (React side)

```tsx
// useAiTools.ts  - React hook to handle incoming tool events

import { useEffect, useState } from "react";
import { socket } from "./socket"; // your websocket

interface PendingTool {
  toolId:   string;
  toolName: string;
  toolArgs: Record<string, any>;
}

export function useAiTools() {
  const [pendingTool, setPendingTool] = useState<PendingTool | null>(null);

  useEffect(() => {
    // AI wants approval for a tool
    socket.on("ai:tool_pending", (data: PendingTool) => {
      setPendingTool(data);
    });

    // Tool finished running
    socket.on("ai:tool_result", (data) => {
      setPendingTool(null);
      console.log("Tool result:", data);
    });

    return () => {
      socket.off("ai:tool_pending");
      socket.off("ai:tool_result");
    };
  }, []);

  // User clicks Approve or Run in Terminal
  const handleApprove = (runInTerminal: boolean) => {
    if (!pendingTool) return;
    socket.emit("tool:approve", {
      toolId: pendingTool.toolId,
      runInTerminal,
    });
  };

  // User clicks ✕
  const handleReject = () => {
    if (!pendingTool) return;
    socket.emit("tool:reject", { toolId: pendingTool.toolId });
    setPendingTool(null);
  };

  return { pendingTool, handleApprove, handleReject };
}
```

```tsx
// In your main App.tsx or Chat.tsx

import { useAiTools } from "./useAiTools";
import { AiToolApproval } from "./AiToolApproval";

export function Chat() {
  const { pendingTool, handleApprove, handleReject } = useAiTools();

  return (
    <div>
      {/* Your chat messages here */}

      {/* Tool approval card appears when AI wants to do something */}
      {pendingTool && (
        <AiToolApproval
          toolName={pendingTool.toolName}
          toolArgs={pendingTool.toolArgs}
          onApprove={handleApprove}
          onReject={handleReject}
        />
      )}
    </div>
  );
}
```

---

## Final Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        AI Response                          │
│              "I need to run: npm install"                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  AiToolApproval Card                        │
│  ┌─────────────────────────────────────────┐                │
│  │  $ npm install                          │                │
│  └─────────────────────────────────────────┘                │
│  [ ✅ Approve (Background) ] [ 💻 Run in Terminal ] [ ✕ ]  │
└──────────┬──────────────────────┬───────────────────────────┘
           │                      │
     Background              Your Terminal
     (AI reads              (You see it run)
      output)               (AI ALSO reads
                             captured output)
           │                      │
           └──────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            Output fed back to AI                            │
│     AI continues with full context of what happened        │
└─────────────────────────────────────────────────────────────┘
```

---

## Key packages needed

```bash
npm install node-pty        # Real terminal emulation
npm install socket.io       # Frontend ↔ Backend events  
npm install socket.io-client
npm install lucide-react    # Icons in the UI
```

> **The magic**: `injectAndWaitForPrompt()` gives you **both** — the command runs visibly in YOUR terminal AND the AI captures the output to continue intelligently. Best of both worlds! 🎯