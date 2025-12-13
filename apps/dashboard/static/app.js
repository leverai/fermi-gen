/**
 * Fermi Dashboard - Question Review Application
 * 
 * State management for staging, diffing, and committing question changes.
 */

// State
let originalEntries = {};  // uid -> original entry data
let stagedEntries = {};    // uid -> current edited entry data
let expandedUids = new Set();

// DOM Elements
const queryBtn = document.getElementById('queryBtn');
const commitBtn = document.getElementById('commitBtn');
const limitInput = document.getElementById('limit');
const loadingEl = document.getElementById('loading');
const errorEl = document.getElementById('error');
const containerEl = document.getElementById('questionsContainer');
const changeCountEl = document.getElementById('changeCount');
const diffModal = document.getElementById('diffModal');
const diffContent = document.getElementById('diffContent');

// Categories and difficulties for dropdowns
const CATEGORIES = [
    'PLANET_EARTH',
    'HUMANITY_BY_NUMBERS',
    'POP_CULTURE',
    'SHOWER_THOUGHTS',
    'COSMIC_PERSPECTIVE',
    'OTHER'
];

const DIFFICULTIES = ['EASY', 'MEDIUM', 'HARD'];
const STATUSES = ['PENDING_REVIEW', 'APPROVED', 'REJECTED'];

// Event Listeners
queryBtn.addEventListener('click', fetchQuestions);
commitBtn.addEventListener('click', commitChanges);

/**
 * Fetch pending questions from the API.
 */
async function fetchQuestions() {
    const limit = parseInt(limitInput.value) || 50;
    
    showLoading(true);
    hideError();
    
    try {
        const response = await fetch(`/api/questions/pending?limit=${limit}`);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const questions = await response.json();
        
        // Store original state
        originalEntries = {};
        stagedEntries = {};
        expandedUids.clear();
        
        questions.forEach(q => {
            originalEntries[q.uid] = { ...q };
            stagedEntries[q.uid] = { ...q };
        });
        
        renderQuestions();
        updateChangeCount();
        
    } catch (err) {
        showError(`Failed to fetch questions: ${err.message}`);
    } finally {
        showLoading(false);
    }
}

/**
 * Render all questions to the container.
 */
function renderQuestions() {
    const uids = Object.keys(stagedEntries);
    
    if (uids.length === 0) {
        containerEl.innerHTML = `
            <div class="loading">
                <span>No pending questions found. Click "Review Questions" to load.</span>
            </div>
        `;
        return;
    }
    
    containerEl.innerHTML = uids.map(uid => renderQuestionRow(uid)).join('');
    
    // Attach event listeners
    uids.forEach(uid => {
        const headerEl = document.querySelector(`[data-uid="${uid}"] .question-header`);
        headerEl.addEventListener('click', () => toggleExpand(uid));
    });
}

/**
 * Render a single question row.
 */
function renderQuestionRow(uid) {
    const entry = stagedEntries[uid];
    const original = originalEntries[uid];
    const isChanged = hasChanges(uid);
    const isExpanded = expandedUids.has(uid);
    
    return `
        <div class="question-row ${isChanged ? 'changed' : ''} ${isExpanded ? 'expanded' : ''}" data-uid="${uid}">
            <div class="question-header">
                <span class="uid">${uid.slice(0, 8)}...</span>
                <span class="text-preview">${escapeHtml(entry.text)}</span>
                <span class="status ${entry.status}">${entry.status.replace('_', ' ')}</span>
                <span class="category">${formatCategory(entry.category)}</span>
                <span class="change-badge">${isChanged ? '● Modified' : ''}</span>
            </div>
            <div class="question-expanded">
                ${renderExpandedForm(uid)}
            </div>
        </div>
    `;
}

/**
 * Render the expanded edit form for a question.
 */
function renderExpandedForm(uid) {
    const entry = stagedEntries[uid];
    const original = originalEntries[uid];
    
    return `
        <div class="form-grid">
            <div class="form-group full-width">
                <label>Question Text</label>
                <textarea 
                    id="text-${uid}" 
                    class="${entry.text !== original.text ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'text', this.value)"
                >${escapeHtml(entry.text)}</textarea>
            </div>
            
            <div class="form-group">
                <label>Answer Number</label>
                <input 
                    type="number" 
                    step="any"
                    id="number-${uid}" 
                    value="${entry.number}"
                    class="${entry.number !== original.number ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'number', parseFloat(this.value))"
                >
            </div>
            
            <div class="form-group">
                <label>Answer Unit</label>
                <input 
                    type="text" 
                    id="unit-${uid}" 
                    value="${entry.unit || ''}"
                    class="${entry.unit !== original.unit ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'unit', this.value || null)"
                >
            </div>
            
            <div class="form-group full-width">
                <label>Snippet (Source Reference)</label>
                <textarea 
                    id="snippet-${uid}" 
                    class="${entry.snippet !== original.snippet ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'snippet', this.value)"
                >${escapeHtml(entry.snippet)}</textarea>
            </div>
            
            <div class="form-group">
                <label>Category</label>
                <select 
                    id="category-${uid}"
                    class="${entry.category !== original.category ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'category', this.value)"
                >
                    ${CATEGORIES.map(c => `
                        <option value="${c}" ${entry.category === c ? 'selected' : ''}>
                            ${formatCategory(c)}
                        </option>
                    `).join('')}
                </select>
            </div>
            
            <div class="form-group">
                <label>Difficulty</label>
                <select 
                    id="difficulty-${uid}"
                    class="${entry.difficulty !== original.difficulty ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'difficulty', this.value)"
                >
                    ${DIFFICULTIES.map(d => `
                        <option value="${d}" ${entry.difficulty === d ? 'selected' : ''}>
                            ${d}
                        </option>
                    `).join('')}
                </select>
            </div>
            
            <div class="form-group">
                <label>Status</label>
                <select 
                    id="status-${uid}"
                    class="${entry.status !== original.status ? 'changed' : ''}"
                    onchange="updateField('${uid}', 'status', this.value)"
                >
                    ${STATUSES.map(s => `
                        <option value="${s}" ${entry.status === s ? 'selected' : ''}>
                            ${s.replace('_', ' ')}
                        </option>
                    `).join('')}
                </select>
            </div>
            
            <div class="form-group">
                <label>Question ID</label>
                <input type="text" value="${entry.question_id}" disabled>
            </div>
        </div>
        
        <div class="llm-section">
            <h3>LLM Bot Answers</h3>
            <div class="llm-grid">
                <div class="llm-answer">
                    <h4>GPT-5.1</h4>
                    <div class="form-group">
                        <label>Number</label>
                        <input 
                            type="number" 
                            step="any"
                            value="${entry.gpt_5_1_number}"
                            class="${entry.gpt_5_1_number !== original.gpt_5_1_number ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_1_number', parseFloat(this.value))"
                        >
                    </div>
                    <div class="form-group">
                        <label>Unit</label>
                        <input 
                            type="text" 
                            value="${entry.gpt_5_1_unit || ''}"
                            class="${entry.gpt_5_1_unit !== original.gpt_5_1_unit ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_1_unit', this.value || null)"
                        >
                    </div>
                </div>
                
                <div class="llm-answer">
                    <h4>GPT-5-mini</h4>
                    <div class="form-group">
                        <label>Number</label>
                        <input 
                            type="number" 
                            step="any"
                            value="${entry.gpt_5_mini_number}"
                            class="${entry.gpt_5_mini_number !== original.gpt_5_mini_number ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_mini_number', parseFloat(this.value))"
                        >
                    </div>
                    <div class="form-group">
                        <label>Unit</label>
                        <input 
                            type="text" 
                            value="${entry.gpt_5_mini_unit || ''}"
                            class="${entry.gpt_5_mini_unit !== original.gpt_5_mini_unit ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_mini_unit', this.value || null)"
                        >
                    </div>
                </div>
                
                <div class="llm-answer">
                    <h4>GPT-5-nano</h4>
                    <div class="form-group">
                        <label>Number</label>
                        <input 
                            type="number" 
                            step="any"
                            value="${entry.gpt_5_nano_number}"
                            class="${entry.gpt_5_nano_number !== original.gpt_5_nano_number ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_nano_number', parseFloat(this.value))"
                        >
                    </div>
                    <div class="form-group">
                        <label>Unit</label>
                        <input 
                            type="text" 
                            value="${entry.gpt_5_nano_unit || ''}"
                            class="${entry.gpt_5_nano_unit !== original.gpt_5_nano_unit ? 'changed' : ''}"
                            onchange="updateField('${uid}', 'gpt_5_nano_unit', this.value || null)"
                        >
                    </div>
                </div>
            </div>
        </div>
        
        <div class="form-actions">
            <button class="btn btn-success btn-sm" onclick="approveEntry('${uid}')">
                ✓ Approve
            </button>
            <button class="btn btn-danger btn-sm" onclick="rejectEntry('${uid}')">
                ✗ Reject
            </button>
            <button class="btn btn-secondary btn-sm" onclick="showDiff('${uid}')" ${!hasChanges(uid) ? 'disabled' : ''}>
                📋 Show Diff
            </button>
            <button class="btn btn-secondary btn-sm" onclick="resetEntry('${uid}')" ${!hasChanges(uid) ? 'disabled' : ''}>
                ↩ Reset
            </button>
        </div>
    `;
}

/**
 * Toggle row expansion.
 */
function toggleExpand(uid) {
    if (expandedUids.has(uid)) {
        expandedUids.delete(uid);
    } else {
        expandedUids.add(uid);
    }
    renderQuestions();
}

/**
 * Update a field value in staged entries.
 */
function updateField(uid, field, value) {
    stagedEntries[uid][field] = value;
    updateChangeCount();
    
    // Update the row's changed indicator without full re-render
    const rowEl = document.querySelector(`[data-uid="${uid}"]`);
    if (rowEl) {
        if (hasChanges(uid)) {
            rowEl.classList.add('changed');
            rowEl.querySelector('.change-badge').textContent = '● Modified';
        } else {
            rowEl.classList.remove('changed');
            rowEl.querySelector('.change-badge').textContent = '';
        }
    }
    
    // Update field styling
    const fieldEl = document.getElementById(`${field}-${uid}`);
    if (fieldEl) {
        if (stagedEntries[uid][field] !== originalEntries[uid][field]) {
            fieldEl.classList.add('changed');
        } else {
            fieldEl.classList.remove('changed');
        }
    }
}

/**
 * Mark entry as approved.
 */
function approveEntry(uid) {
    updateField(uid, 'status', 'APPROVED');
    // Update the status dropdown
    const selectEl = document.getElementById(`status-${uid}`);
    if (selectEl) selectEl.value = 'APPROVED';
    renderQuestions();
}

/**
 * Mark entry as rejected.
 */
function rejectEntry(uid) {
    updateField(uid, 'status', 'REJECTED');
    // Update the status dropdown
    const selectEl = document.getElementById(`status-${uid}`);
    if (selectEl) selectEl.value = 'REJECTED';
    renderQuestions();
}

/**
 * Reset entry to original state.
 */
function resetEntry(uid) {
    stagedEntries[uid] = { ...originalEntries[uid] };
    updateChangeCount();
    renderQuestions();
}

/**
 * Check if an entry has changes.
 */
function hasChanges(uid) {
    const original = originalEntries[uid];
    const staged = stagedEntries[uid];
    
    const fields = [
        'text', 'number', 'unit', 'snippet', 'category', 'difficulty', 'status',
        'gpt_5_1_number', 'gpt_5_1_unit',
        'gpt_5_mini_number', 'gpt_5_mini_unit',
        'gpt_5_nano_number', 'gpt_5_nano_unit'
    ];
    
    return fields.some(f => original[f] !== staged[f]);
}

/**
 * Get list of changed fields for an entry.
 */
function getChangedFields(uid) {
    const original = originalEntries[uid];
    const staged = stagedEntries[uid];
    
    const fields = [
        'text', 'number', 'unit', 'snippet', 'category', 'difficulty', 'status',
        'gpt_5_1_number', 'gpt_5_1_unit',
        'gpt_5_mini_number', 'gpt_5_mini_unit',
        'gpt_5_nano_number', 'gpt_5_nano_unit'
    ];
    
    return fields
        .filter(f => original[f] !== staged[f])
        .map(f => ({
            field: f,
            oldValue: original[f],
            newValue: staged[f]
        }));
}

/**
 * Show diff modal for an entry.
 */
function showDiff(uid) {
    const changes = getChangedFields(uid);
    
    if (changes.length === 0) {
        return;
    }
    
    diffContent.innerHTML = `
        <p style="margin-bottom: 1rem; color: var(--text-secondary);">
            Changes for question ${uid.slice(0, 8)}...
        </p>
        ${changes.map(c => `
            <div class="diff-item">
                <div class="field-name">${c.field}</div>
                <div class="old-value">- ${formatValue(c.oldValue)}</div>
                <div class="new-value">+ ${formatValue(c.newValue)}</div>
            </div>
        `).join('')}
    `;
    
    diffModal.classList.remove('hidden');
}

/**
 * Close diff modal.
 */
function closeDiffModal() {
    diffModal.classList.add('hidden');
}

// Close modal on backdrop click
diffModal.addEventListener('click', (e) => {
    if (e.target === diffModal) {
        closeDiffModal();
    }
});

/**
 * Update the change count display.
 */
function updateChangeCount() {
    const changedCount = Object.keys(stagedEntries).filter(uid => hasChanges(uid)).length;
    
    if (changedCount > 0) {
        changeCountEl.textContent = `${changedCount} ${changedCount === 1 ? 'change' : 'changes'} staged`;
        changeCountEl.classList.remove('hidden');
        commitBtn.disabled = false;
    } else {
        changeCountEl.classList.add('hidden');
        commitBtn.disabled = true;
    }
}

/**
 * Commit all staged changes.
 */
async function commitChanges() {
    const changedUids = Object.keys(stagedEntries).filter(uid => hasChanges(uid));
    
    if (changedUids.length === 0) {
        return;
    }
    
    const updates = changedUids.map(uid => {
        const staged = stagedEntries[uid];
        const original = originalEntries[uid];
        
        // Build update object with only changed fields
        const update = { uid };
        
        const fields = [
            'text', 'number', 'unit', 'snippet', 'category', 'difficulty', 'status',
            'gpt_5_1_number', 'gpt_5_1_unit',
            'gpt_5_mini_number', 'gpt_5_mini_unit',
            'gpt_5_nano_number', 'gpt_5_nano_unit'
        ];
        
        fields.forEach(f => {
            if (staged[f] !== original[f]) {
                update[f] = staged[f];
            }
        });
        
        return update;
    });
    
    commitBtn.disabled = true;
    commitBtn.innerHTML = '<span class="spinner"></span> Committing...';
    
    try {
        const response = await fetch('/api/questions/commit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ updates })
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || `HTTP ${response.status}`);
        }
        
        const result = await response.json();
        
        // Update original entries to match committed state
        changedUids.forEach(uid => {
            originalEntries[uid] = { ...stagedEntries[uid] };
        });
        
        updateChangeCount();
        renderQuestions();
        
        // Show success message
        alert(`✓ ${result.message}`);
        
    } catch (err) {
        showError(`Failed to commit changes: ${err.message}`);
    } finally {
        commitBtn.disabled = false;
        commitBtn.innerHTML = '<span class="icon">✓</span> Commit Changes';
    }
}

// Utility Functions

function showLoading(show) {
    loadingEl.classList.toggle('hidden', !show);
}

function showError(message) {
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
}

function hideError() {
    errorEl.classList.add('hidden');
}

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function formatCategory(category) {
    if (!category) return 'N/A';
    return category
        .split('_')
        .map(w => w.charAt(0) + w.slice(1).toLowerCase())
        .join(' ');
}

function formatValue(value) {
    if (value === null || value === undefined) return 'null';
    if (typeof value === 'string' && value.length > 100) {
        return value.slice(0, 100) + '...';
    }
    return String(value);
}
