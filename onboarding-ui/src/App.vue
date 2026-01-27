<template>
  <div class="app">
    <header class="header">
      <div class="container">
        <h1>🦞 Moltbot Onboarding</h1>
        <p class="subtitle">Interactive setup wizard</p>
      </div>
    </header>

    <main class="main">
      <div class="container">
        <!-- Command Selection -->
        <div v-if="!sessionActive" class="command-selector">
          <h2>Choose a setup command</h2>
          <div class="commands">
            <button
              v-for="cmd in commands"
              :key="cmd.id"
              @click="startCommand(cmd)"
              class="command-button"
            >
              <span class="command-name">{{ cmd.name }}</span>
              <span class="command-cmd">{{ cmd.command }} {{ cmd.args.join(' ') }}</span>
            </button>
          </div>
        </div>

        <!-- Terminal View -->
        <div v-else class="terminal-container">
          <div class="terminal-header">
            <span class="terminal-title">{{ currentCommand?.name || 'Terminal' }}</span>
            <div class="terminal-controls">
              <button @click="clearTerminal" class="btn-icon" title="Clear">
                🗑️
              </button>
              <button @click="stopSession" class="btn-icon btn-danger" title="Stop">
                ⏹️
              </button>
            </div>
          </div>

          <div ref="terminalOutput" class="terminal-output">
            <div v-html="formattedOutput"></div>
            <div v-if="!sessionEnded" class="cursor-blink">_</div>
          </div>

          <div class="terminal-input">
            <span class="prompt">></span>
            <input
              ref="terminalInput"
              v-model="inputBuffer"
              @keydown.enter="sendInput"
              @keydown.up="historyPrev"
              @keydown.down="historyNext"
              placeholder="Type your response..."
              :disabled="sessionEnded"
              autocomplete="off"
            />
          </div>

          <div v-if="sessionEnded" class="session-ended">
            <p>Session ended (exit code: {{ exitCode }})</p>
            <button @click="resetSession" class="btn-primary">Start New Session</button>
          </div>
        </div>

        <!-- Status Info -->
        <div class="status-bar">
          <span v-if="connected" class="status-connected">● Connected</span>
          <span v-else class="status-disconnected">● Disconnected</span>
          <span v-if="sessionActive" class="status-info">Session: {{ sessionId }}</span>
        </div>
      </div>
    </main>

    <footer class="footer">
      <div class="container">
        <p>Moltbot Onboarding UI • Running on port {{ port }}</p>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'

// State
const ws = ref(null)
const connected = ref(false)
const sessionActive = ref(false)
const sessionEnded = ref(false)
const sessionId = ref(null)
const currentCommand = ref(null)
const outputBuffer = ref('')
const inputBuffer = ref('')
const inputHistory = ref([])
const historyIndex = ref(-1)
const exitCode = ref(null)
const commands = ref([])
const port = ref(window.location.port || 18790)

// Refs
const terminalOutput = ref(null)
const terminalInput = ref(null)

// Computed
const formattedOutput = computed(() => {
  return ansiToHtml(outputBuffer.value)
})

// WebSocket connection
function connectWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  const wsUrl = `${protocol}//${window.location.hostname}:${port.value}`
  
  ws.value = new WebSocket(wsUrl)

  ws.value.onopen = () => {
    console.log('[WS] Connected')
    connected.value = true
  }

  ws.value.onmessage = (event) => {
    const data = JSON.parse(event.data)
    handleWebSocketMessage(data)
  }

  ws.value.onclose = () => {
    console.log('[WS] Disconnected')
    connected.value = false
    setTimeout(connectWebSocket, 3000)
  }

  ws.value.onerror = (error) => {
    console.error('[WS] Error:', error)
  }
}

// Handle WebSocket messages
function handleWebSocketMessage(data) {
  switch (data.type) {
    case 'started':
      sessionId.value = data.sessionId
      console.log('[Session] Started:', sessionId.value)
      break

    case 'output':
      outputBuffer.value += data.data
      scrollToBottom()
      break

    case 'exit':
      console.log('[Session] Exited:', data.exitCode)
      sessionEnded.value = true
      exitCode.value = data.exitCode
      break

    case 'killed':
      console.log('[Session] Killed')
      resetSession()
      break

    case 'error':
      console.error('[Session] Error:', data.message)
      outputBuffer.value += `\n\n❌ Error: ${data.message}\n`
      break
  }
}

// Start a command
function startCommand(cmd) {
  currentCommand.value = cmd
  sessionActive.value = true
  sessionEnded.value = false
  outputBuffer.value = ''
  exitCode.value = null
  
  if (ws.value && ws.value.readyState === WebSocket.OPEN) {
    ws.value.send(JSON.stringify({
      type: 'start',
      command: cmd.command,
      args: cmd.args
    }))
  }

  nextTick(() => {
    terminalInput.value?.focus()
  })
}

// Send input to terminal
function sendInput() {
  if (!inputBuffer.value || sessionEnded.value) return

  const input = inputBuffer.value + '\n'
  
  if (ws.value && ws.value.readyState === WebSocket.OPEN) {
    ws.value.send(JSON.stringify({
      type: 'input',
      data: input
    }))
  }

  inputHistory.value.push(inputBuffer.value)
  historyIndex.value = inputHistory.value.length
  inputBuffer.value = ''
}

// Stop session
function stopSession() {
  if (ws.value && ws.value.readyState === WebSocket.OPEN) {
    ws.value.send(JSON.stringify({ type: 'kill' }))
  }
}

// Reset session
function resetSession() {
  sessionActive.value = false
  sessionEnded.value = false
  sessionId.value = null
  currentCommand.value = null
  outputBuffer.value = ''
  inputBuffer.value = ''
  exitCode.value = null
}

// Clear terminal
function clearTerminal() {
  outputBuffer.value = ''
}

// Input history navigation
function historyPrev(e) {
  e.preventDefault()
  if (historyIndex.value > 0) {
    historyIndex.value--
    inputBuffer.value = inputHistory.value[historyIndex.value] || ''
  }
}

function historyNext(e) {
  e.preventDefault()
  if (historyIndex.value < inputHistory.value.length - 1) {
    historyIndex.value++
    inputBuffer.value = inputHistory.value[historyIndex.value] || ''
  } else {
    historyIndex.value = inputHistory.value.length
    inputBuffer.value = ''
  }
}

// Scroll terminal to bottom
function scrollToBottom() {
  nextTick(() => {
    if (terminalOutput.value) {
      terminalOutput.value.scrollTop = terminalOutput.value.scrollHeight
    }
  })
}

// Simple ANSI to HTML converter
function ansiToHtml(text) {
  const colors = {
    '30': '#000', '31': '#e74c3c', '32': '#2ecc71', '33': '#f39c12',
    '34': '#3498db', '35': '#9b59b6', '36': '#1abc9c', '37': '#ecf0f1',
    '90': '#7f8c8d', '91': '#e67e22', '92': '#27ae60', '93': '#f1c40f',
    '94': '#2980b9', '95': '#8e44ad', '96': '#16a085', '97': '#bdc3c7'
  }

  let html = text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\n/g, '<br>')
    .replace(/ {2}/g, '&nbsp;&nbsp;')

  // Handle ANSI color codes
  html = html.replace(/\x1b\[(\d+)m/g, (match, code) => {
    if (code === '0') return '</span>'
    if (code === '1') return '<span style="font-weight:bold">'
    if (colors[code]) return `<span style="color:${colors[code]}">`
    return ''
  })

  // Remove other ANSI escape sequences
  html = html.replace(/\x1b\[\??[0-9;]*[A-Za-z]/g, '')

  return html
}

// Fetch available commands
async function fetchCommands() {
  try {
    const response = await fetch('/api/commands')
    const data = await response.json()
    commands.value = data.commands
  } catch (error) {
    console.error('[API] Failed to fetch commands:', error)
    // Fallback commands
    commands.value = [
      { id: 'onboard', name: 'Full Onboarding', command: 'moltbot', args: ['onboard'] },
      { id: 'configure', name: 'Configure', command: 'moltbot', args: ['configure'] },
      { id: 'doctor', name: 'Health Check', command: 'moltbot', args: ['doctor'] }
    ]
  }
}

// Lifecycle
onMounted(() => {
  connectWebSocket()
  fetchCommands()
})

onUnmounted(() => {
  if (ws.value) {
    ws.value.close()
  }
})
</script>

<style scoped>
.app {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1rem;
  width: 100%;
}

/* Header */
.header {
  background: var(--bg-light);
  border-bottom: 2px solid var(--primary);
  padding: 1.5rem 0;
}

.header h1 {
  font-size: 2rem;
  margin-bottom: 0.25rem;
}

.subtitle {
  color: var(--text-dim);
  font-size: 0.9rem;
}

/* Main */
.main {
  flex: 1;
  padding: 2rem 0;
}

/* Command Selector */
.command-selector {
  max-width: 800px;
  margin: 0 auto;
}

.command-selector h2 {
  margin-bottom: 1.5rem;
  text-align: center;
}

.commands {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1rem;
}

.command-button {
  background: var(--bg-light);
  border: 2px solid var(--border);
  border-radius: 8px;
  padding: 1.5rem;
  text-align: left;
  transition: all 0.2s;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.command-button:hover {
  border-color: var(--primary);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 161, 228, 0.2);
}

.command-name {
  font-size: 1.1rem;
  font-weight: 600;
  color: var(--text);
}

.command-cmd {
  font-family: 'Menlo', monospace;
  font-size: 0.85rem;
  color: var(--text-dim);
}

/* Terminal */
.terminal-container {
  background: var(--bg-light);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  max-width: 1000px;
  margin: 0 auto;
}

.terminal-header {
  background: #1e2530;
  padding: 0.75rem 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
}

.terminal-title {
  font-weight: 600;
}

.terminal-controls {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  background: transparent;
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 0.25rem 0.5rem;
  font-size: 1rem;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: var(--border);
}

.btn-danger:hover {
  background: var(--error);
  border-color: var(--error);
}

.terminal-output {
  background: #0d1117;
  padding: 1rem;
  height: 500px;
  overflow-y: auto;
  font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
  font-size: 14px;
  line-height: 1.5;
  color: var(--text);
}

.terminal-output :deep(br) {
  display: block;
  content: "";
  margin: 0;
}

.cursor-blink {
  display: inline-block;
  animation: blink 1s step-end infinite;
  color: var(--primary);
}

@keyframes blink {
  50% { opacity: 0; }
}

.terminal-input {
  background: #0d1117;
  border-top: 1px solid var(--border);
  padding: 0.75rem 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.prompt {
  color: var(--primary);
  font-weight: bold;
  font-family: monospace;
}

.terminal-input input {
  flex: 1;
  background: transparent;
  border: none;
  color: var(--text);
  font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
  font-size: 14px;
  outline: none;
}

.session-ended {
  background: var(--bg-light);
  border-top: 1px solid var(--border);
  padding: 1rem;
  text-align: center;
}

.btn-primary {
  background: var(--primary);
  border: none;
  border-radius: 6px;
  color: white;
  padding: 0.75rem 1.5rem;
  font-weight: 600;
  margin-top: 1rem;
  transition: background 0.2s;
}

.btn-primary:hover {
  background: var(--primary-dark);
}

/* Status Bar */
.status-bar {
  background: var(--bg-light);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0.75rem 1rem;
  margin-top: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.9rem;
  max-width: 1000px;
  margin: 1rem auto 0;
}

.status-connected {
  color: var(--success);
}

.status-disconnected {
  color: var(--error);
}

.status-info {
  color: var(--text-dim);
  font-family: monospace;
  font-size: 0.85rem;
}

/* Footer */
.footer {
  background: var(--bg-light);
  border-top: 1px solid var(--border);
  padding: 1rem 0;
  text-align: center;
  color: var(--text-dim);
  font-size: 0.9rem;
}
</style>
