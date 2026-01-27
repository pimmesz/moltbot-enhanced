#!/usr/bin/env node

/**
 * Moltbot Onboarding Web UI - Backend Server
 * 
 * This server provides a WebSocket API to interact with the moltbot CLI
 * in an interactive way, allowing web-based onboarding.
 */

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const pty = require('node-pty');
const path = require('path');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Configuration
const PORT = process.env.ONBOARDING_PORT || 18790;
const MOLTBOT_BINARY = process.env.MOLTBOT_BINARY || 'moltbot';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../dist')));

// Store active PTY sessions
const sessions = new Map();

/**
 * Create a new PTY session for moltbot command
 */
function createMoltbotSession(command, args = []) {
  const ptyProcess = pty.spawn(command, args, {
    name: 'xterm-color',
    cols: 120,
    rows: 30,
    cwd: process.env.HOME || '/config',
    env: {
      ...process.env,
      TERM: 'xterm-color',
      COLORTERM: 'truecolor'
    }
  });

  const sessionId = Math.random().toString(36).substring(7);
  
  sessions.set(sessionId, {
    pty: ptyProcess,
    command,
    args,
    createdAt: Date.now()
  });

  return { sessionId, ptyProcess };
}

/**
 * WebSocket connection handler
 */
wss.on('connection', (ws) => {
  console.log('[WebSocket] Client connected');
  
  let currentSession = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('[WebSocket] Received:', data.type);

      switch (data.type) {
        case 'start':
          // Start a new moltbot session
          const { command = 'moltbot', args = ['onboard'] } = data;
          
          // Clean up any existing session for this client
          if (currentSession && sessions.has(currentSession)) {
            const session = sessions.get(currentSession);
            session.pty.kill();
            sessions.delete(currentSession);
          }

          const { sessionId, ptyProcess } = createMoltbotSession(command, args);
          currentSession = sessionId;

          // Forward PTY output to WebSocket
          ptyProcess.onData((data) => {
            ws.send(JSON.stringify({
              type: 'output',
              data: data
            }));
          });

          // Handle PTY exit
          ptyProcess.onExit(({ exitCode, signal }) => {
            console.log(`[PTY] Process exited with code ${exitCode}, signal ${signal}`);
            ws.send(JSON.stringify({
              type: 'exit',
              exitCode,
              signal
            }));
            sessions.delete(sessionId);
            currentSession = null;
          });

          ws.send(JSON.stringify({
            type: 'started',
            sessionId
          }));
          break;

        case 'input':
          // Send input to PTY
          if (currentSession && sessions.has(currentSession)) {
            const session = sessions.get(currentSession);
            session.pty.write(data.data);
          } else {
            ws.send(JSON.stringify({
              type: 'error',
              message: 'No active session'
            }));
          }
          break;

        case 'resize':
          // Resize PTY
          if (currentSession && sessions.has(currentSession)) {
            const session = sessions.get(currentSession);
            session.pty.resize(data.cols || 120, data.rows || 30);
          }
          break;

        case 'kill':
          // Kill the session
          if (currentSession && sessions.has(currentSession)) {
            const session = sessions.get(currentSession);
            session.pty.kill();
            sessions.delete(currentSession);
            currentSession = null;
            ws.send(JSON.stringify({ type: 'killed' }));
          }
          break;

        default:
          console.warn('[WebSocket] Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('[WebSocket] Error processing message:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: error.message
      }));
    }
  });

  ws.on('close', () => {
    console.log('[WebSocket] Client disconnected');
    // Clean up session
    if (currentSession && sessions.has(currentSession)) {
      const session = sessions.get(currentSession);
      session.pty.kill();
      sessions.delete(currentSession);
    }
  });

  ws.on('error', (error) => {
    console.error('[WebSocket] Error:', error);
  });
});

// API Routes
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    sessions: sessions.size,
    uptime: process.uptime()
  });
});

app.get('/api/commands', (req, res) => {
  res.json({
    commands: [
      { id: 'onboard', name: 'Full Onboarding', command: 'moltbot', args: ['onboard'] },
      { id: 'configure', name: 'Configure', command: 'moltbot', args: ['configure'] },
      { id: 'doctor', name: 'Health Check', command: 'moltbot', args: ['doctor'] },
      { id: 'channels', name: 'Add Channels', command: 'moltbot', args: ['channels', 'login'] },
      { id: 'status', name: 'Status', command: 'moltbot', args: ['status'] }
    ]
  });
});

// Serve Vue app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../dist/index.html'));
});

// Cleanup on exit
process.on('SIGTERM', () => {
  console.log('[Server] Shutting down...');
  sessions.forEach((session) => {
    session.pty.kill();
  });
  server.close(() => {
    process.exit(0);
  });
});

// Start server
// Bind to 0.0.0.0 to allow access from network (not just localhost)
server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Server] Moltbot Onboarding UI listening on 0.0.0.0:${PORT}`);
  console.log(`[Server] WebSocket server ready`);
  console.log(`[Server] Accessible at http://localhost:${PORT} or http://<server-ip>:${PORT}`);
});

// Handle server errors
server.on('error', (error) => {
  console.error(`[Server] Error starting server:`, error);
  if (error.code === 'EADDRINUSE') {
    console.error(`[Server] Port ${PORT} is already in use`);
  }
  process.exit(1);
});
