let wasm = null;
let wasmMemory = null;

// Dark mode toggle
const themeToggle = document.getElementById('themeToggle');
const html = document.documentElement;

// Check for saved theme preference or default to system preference
const savedTheme = localStorage.getItem('theme');
const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

if (savedTheme) {
  html.setAttribute('data-theme', savedTheme);
} else if (systemPrefersDark) {
  html.setAttribute('data-theme', 'dark');
}

themeToggle.addEventListener('click', () => {
  const currentTheme = html.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

  html.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
});

// Initialize WASM
async function initWasm() {
  try {
    const wasmModule = await WebAssembly.instantiateStreaming(fetch("zjview.wasm"), {});
    wasm = wasmModule.instance.exports;
    wasmMemory = new Uint8Array(wasm.memory.buffer);
    console.log("WASM initialized:", Object.keys(wasm));
  } catch (error) {
    showError("Failed to load WASM module: " + error.message);
  }
}

// Helper functions
function showStatus(message, type = 'info') {
  const statusDiv = document.getElementById('status');
  statusDiv.className = type;
  statusDiv.textContent = message;
}

function showResults() {
  const resultsDiv = document.getElementById('results');
  resultsDiv.style.display = 'flex';
}

function hideResults() {
  const resultsDiv = document.getElementById('results');
  resultsDiv.style.display = 'none';
}

function showError(message) {
  showStatus(message, 'error');
  hideResults();
}

function showSuccess(message) {
  showStatus(message, 'success');
}

function showLoading(message) {
  showStatus(message, 'loading');
}

function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function updateStats() {
  document.getElementById('fileSize').textContent = formatFileSize(wasm.get_file_size().toLocaleString());
  document.getElementById('totalKeys').textContent = wasm.get_total_keys().toLocaleString();
  document.getElementById('totalObjects').textContent = wasm.get_total_objects().toLocaleString();
  document.getElementById('totalArrays').textContent = wasm.get_total_arrays().toLocaleString();
  document.getElementById('maxDepth').textContent = wasm.get_max_depth().toLocaleString();
  document.getElementById('stats').style.display = 'grid';
  showResults();
}

function writeDataToWasm(data) {
  const bufferPtr = wasm.get_json_buffer();
  const bufferSize = wasm.get_json_buffer_size();

  if (data.length > bufferSize) {
    throw new Error(`Data too large: ${data.length} bytes, max: ${bufferSize} bytes`);
  }

  const bytes = new TextEncoder().encode(data);
  wasmMemory.set(bytes, bufferPtr);
  wasm.set_json_length(bytes.length);

  return bytes.length;
}

function readResultFromWasm() {
  const resultPtr = wasm.get_result_buffer();
  const resultLen = wasm.get_result_length();

  if (resultLen === 0) return "";

  const bytes = wasmMemory.slice(resultPtr, resultPtr + resultLen);
  return new TextDecoder().decode(bytes);
}

async function processJSON(jsonData) {
  if (!wasm) {
    showError("WASM not initialized");
    return;
  }

  try {
    showLoading("Processing JSON...");

    // Write data to WASM
    const dataSize = writeDataToWasm(jsonData);
    console.log(`Data written to WASM: ${dataSize} bytes`);

    // Process JSON
    const result = wasm.process_json();

    if (result === 0) {
      showSuccess("JSON processed successfully!");
      updateStats();
    } else {
      const errorMsg = result === -1 ? "Empty input" : "Invalid JSON";
      showError(errorMsg);
    }
  } catch (error) {
    showError("Processing error: " + error.message);
  }
}

// Event listeners
document.getElementById('fileInput').addEventListener('change', async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  try {
    showLoading("Reading file...");
    const text = await file.text();
    await processJSON(text);
  } catch (error) {
    hideResults();
    showError("File reading error: " + error.message);
  }
});

document.getElementById('extractKeysButton').addEventListener('click', () => {
  if (!wasm) return;

  try {
    const keysLen = wasm.extract_all_keys();
    if (keysLen > 0) {
      const keysData = readResultFromWasm();
      const keys = keysData.split('\n').filter(k => k.trim().length > 0);

      const keysList = document.getElementById('keysList');
      keysList.innerHTML = keys.map(key =>
        `<div class="key-item" onclick="searchKey('${key.replace(/'/g, "\\'")}')">${key}</div>`
      ).join('');

      showSuccess(`Extracted ${keys.length} keys`);
    } else {
      showError("No keys found");
    }
  } catch (error) {
    showError("Key extraction error: " + error.message);
  }
});

document.getElementById('searchButton').addEventListener('click', () => {
  const key = document.getElementById('keySearch').value.trim();
  if (key) {
    searchKey(key);
  }
});

function searchKey(key) {
  if (!wasm) return;

  try {
    // Write key to memory
    const keyBytes = new TextEncoder().encode(key);
    const keyPtr = 5000; // Use a different offset for key
    wasmMemory.set(keyBytes, keyPtr);

    const valueLen = wasm.get_key_value(keyPtr, keyBytes.length);

    if (valueLen > 0) {
      const value = readResultFromWasm();
      document.getElementById('keyValue').innerHTML =
        `<strong>Value:</strong><pre>${value}</pre>`;
      document.getElementById('keySearch').value = key;
    } else {
      document.getElementById('keyValue').innerHTML = `<em>Key "${key}" not found</em>`;
    }
  } catch (error) {
    showError("Search error: " + error.message);
  }
}

// Initialize when page loads
window.addEventListener('load', initWasm);