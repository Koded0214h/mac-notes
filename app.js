const STORAGE_KEY = 'field-notes-v1';

const seedNotes = [
  { id: 'shape-day', title: 'The shape of a good day', content: `A good day has room around the edges.\n\nIt starts slowly, with a small useful thing, and gets a little more interesting as it goes. There is enough margin to notice the light changing on the wall.\n\nThe goal is not to fit more in. It is to leave a little space for the unexpected.\n\n— notes from this morning`, pinned: true, updatedAt: Date.now() - 1000 * 60 * 4 },
  { id: 'morning-walk', title: 'Morning walk', content: `- take the long way home\n- look for the first jacaranda bloom\n- pick up coffee beans\n\n> Let the day arrive before you ask it to perform.`, pinned: false, updatedAt: Date.now() - 1000 * 60 * 60 * 3 },
  { id: 'tiny-ideas', title: 'Tiny ideas', content: `A shelf for things that are not ready yet.\n\n- a reading list that feels like a walk\n- one window, one task\n- a keyboard shortcut that feels like a door\n\n\`\`\`js\nconst gentleness = (task) => task.withMoreMargin();\n\`\`\``, pinned: false, updatedAt: Date.now() - 1000 * 60 * 60 * 24 },
];

let state = loadState();
let saveTimer;
let toastTimer;
const initialTheme = localStorage.getItem('field-notes-theme') || 'light';

const els = {
  notesList: document.querySelector('#notesList'), search: document.querySelector('#searchInput'),
  title: document.querySelector('#noteTitle'), content: document.querySelector('#noteContent'),
  count: document.querySelector('#noteCount'), words: document.querySelector('#wordCount'),
  saveState: document.querySelector('#saveState'), saveWrap: document.querySelector('.save-state'),
  edited: document.querySelector('#editedLabel'), pin: document.querySelector('#pinButton'), toast: document.querySelector('#toast')
};
const preview = document.querySelector('#markdownPreview');
const editorWrap = document.querySelector('.editor-wrap');

function loadState() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (stored?.notes?.length) return stored;
  } catch (error) { console.warn('Could not read local notes', error); }
  return { notes: seedNotes, activeId: seedNotes[0].id };
}

function persist() { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }
function activeNote() { return state.notes.find(note => note.id === state.activeId) || state.notes[0]; }
function formatDate(timestamp) {
  const diff = Date.now() - timestamp;
  if (diff < 60000) return 'just now';
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
  return new Date(timestamp).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}
function renderList() {
  const query = els.search.value.trim().toLowerCase();
  const notes = [...state.notes].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.updatedAt - a.updatedAt)
    .filter(note => !query || `${note.title} ${note.content}`.toLowerCase().includes(query));
  els.count.textContent = state.notes.length;
  els.notesList.innerHTML = notes.length ? notes.map(note => `
    <button class="note-item ${note.id === state.activeId ? 'active' : ''}" data-note-id="${note.id}" role="option" aria-selected="${note.id === state.activeId}">
      <div class="note-item-title"><span>${escapeHtml(note.title || 'Untitled note')}</span>${note.pinned ? '<span class="note-pin">✦</span>' : ''}</div>
      <div class="note-item-preview">${escapeHtml(note.content.replace(/\n/g, ' ').slice(0, 48) || 'Empty note')}</div>
      <div class="note-item-meta"><span>${formatDate(note.updatedAt)}</span><span>${countWords(note.content)} words</span></div>
    </button>`).join('') : `<div class="empty-list">No notes found</div>`;
  els.notesList.querySelectorAll('[data-note-id]').forEach(button => button.addEventListener('click', () => selectNote(button.dataset.noteId)));
}
function renderEditor() {
  const note = activeNote();
  if (!note) return;
  els.title.value = note.title;
  els.content.value = note.content;
  els.edited.textContent = `Edited ${formatDate(note.updatedAt)}`;
  els.pin.textContent = note.pinned ? '★' : '☆';
  els.pin.setAttribute('aria-label', note.pinned ? 'Unpin note' : 'Pin note');
  updateCounts();
  if (editorWrap.classList.contains('previewing')) renderPreview();
}
function selectNote(id) { if (!state.notes.some(n => n.id === id)) return; flushSave(); state.activeId = id; persist(); renderList(); renderEditor(); els.content.focus(); }
function moveNote(direction) {
  const ordered = [...state.notes].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.updatedAt - a.updatedAt);
  const current = ordered.findIndex(note => note.id === state.activeId);
  const next = ordered[(current + direction + ordered.length) % ordered.length];
  if (next) selectNote(next.id);
}
function countWords(text) { return (text.trim().match(/\S+/g) || []).length; }
function updateCounts() { els.words.textContent = `${countWords(els.content.value)} words`; }
function escapeHtml(value) { return value.replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[char])); }
function renderPreview() {
  let html = escapeHtml(els.content.value);
  html = html.replace(/^### (.*)$/gm, '<h3>$1</h3>').replace(/^## (.*)$/gm, '<h2>$1</h2>').replace(/^# (.*)$/gm, '<h1>$1</h1>');
  html = html.replace(/^```(?:\w+)?\n([\s\S]*?)```/gm, '<pre>$1</pre>').replace(/^> (.*)$/gm, '<blockquote>$1</blockquote>');
  html = html.replace(/^- \[ \] (.*)$/gm, '<p>☐ $1</p>').replace(/^- \[x\] (.*)$/gim, '<p>☑ $1</p>');
  html = html.replace(/^- (.*)$/gm, '<li>$1</li>').replace(/(<li>.*<\/li>\n?)+/g, block => `<ul>${block}</ul>`);
  html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/_(.*?)_/g, '<em>$1</em>').replace(/`([^`]+)`/g, '<code>$1</code>');
  html = html.split(/\n{2,}/).map(block => /^<(h|ul|pre|blockquote)/.test(block.trim()) ? block : `<p>${block.replace(/\n/g, '<br>')}</p>`).join('');
  preview.innerHTML = html;
}
function markDirty() {
  els.saveWrap.classList.add('saving'); els.saveState.textContent = 'Saving…';
  clearTimeout(saveTimer); saveTimer = setTimeout(flushSave, 550);
}
function flushSave() {
  const note = activeNote(); if (!note) return;
  note.title = els.title.value.trim() || 'Untitled note'; note.content = els.content.value; note.updatedAt = Date.now();
  persist(); renderList(); els.edited.textContent = 'Edited just now'; els.saveWrap.classList.remove('saving'); els.saveState.textContent = 'Saved locally';
}
function showToast(message) { clearTimeout(toastTimer); els.toast.textContent = message; els.toast.classList.add('show'); toastTimer = setTimeout(() => els.toast.classList.remove('show'), 2200); }
function createNote() {
  flushSave(); const note = { id: `note-${Date.now()}`, title: 'Untitled note', content: '', pinned: false, updatedAt: Date.now() };
  state.notes.push(note); state.activeId = note.id; persist(); renderList(); renderEditor(); els.title.focus(); els.title.select(); showToast('New note ready');
}
function deleteNote() {
  if (state.notes.length <= 1) { showToast('Keep at least one note'); return; }
  const note = activeNote(); if (!confirm(`Delete “${note.title}”?`)) return;
  const index = state.notes.findIndex(n => n.id === note.id); state.notes.splice(index, 1); state.activeId = state.notes[Math.max(0, index - 1)].id; persist(); renderList(); renderEditor(); showToast('Note deleted');
}
function insertFormat(type) {
  const start = els.content.selectionStart, end = els.content.selectionEnd, selected = els.content.value.slice(start, end);
  const wraps = { bold: ['**', '**'], italic: ['_', '_'], heading: ['## ', ''], bullet: ['- ', ''], check: ['- [ ] ', ''], code: ['`', '`'], quote: ['> ', ''] };
  const pair = wraps[type]; if (!pair) return;
  const replacement = `${pair[0]}${selected || (type === 'heading' ? 'Heading' : 'text')}${pair[1]}`;
  els.content.setRangeText(replacement, start, end, 'select'); els.content.focus(); markDirty(); updateCounts();
}

function applyTheme(theme) {
  const isDark = theme === 'dark';
  document.body.classList.toggle('dark-mode', isDark);
  const button = document.querySelector('#themeToggle');
  button.textContent = isDark ? '☀' : '☾';
  button.setAttribute('aria-label', isDark ? 'Use light mode' : 'Use dark mode');
  button.setAttribute('title', isDark ? 'Use light mode' : 'Use dark mode');
  localStorage.setItem('field-notes-theme', theme);
}

document.querySelector('#newNoteButton').addEventListener('click', createNote);
document.querySelector('#searchInput').addEventListener('input', renderList);
document.querySelector('#pinButton').addEventListener('click', () => { const note = activeNote(); note.pinned = !note.pinned; note.updatedAt = Date.now(); persist(); renderList(); renderEditor(); showToast(note.pinned ? 'Pinned to the top' : 'Removed from pinned'); });
document.querySelector('#themeToggle').addEventListener('click', () => { const nextTheme = document.body.classList.contains('dark-mode') ? 'light' : 'dark'; applyTheme(nextTheme); showToast(`${nextTheme === 'dark' ? 'Dark' : 'Light'} mode enabled`); });
document.querySelector('#moreButton').addEventListener('click', deleteNote);
document.querySelector('#revealButton').addEventListener('click', () => showToast('Notes are stored in your local Field Notes folder'));
document.querySelector('#exportButton').addEventListener('click', () => {
  flushSave(); const note = activeNote(); const blob = new Blob([note.content], { type: 'text/markdown;charset=utf-8' });
  const link = document.createElement('a'); link.href = URL.createObjectURL(blob); link.download = `${(note.title || 'untitled-note').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'untitled-note'}.md`; link.click(); URL.revokeObjectURL(link.href); showToast('Markdown file exported');
});
document.querySelector('#importButton').addEventListener('click', () => document.querySelector('#importInput').click());
document.querySelector('#importInput').addEventListener('change', async event => {
  const file = event.target.files?.[0];
  if (!file) return;
  const content = await file.text();
  const title = file.name.replace(/\.(markdown|md)$/i, '').replace(/[-_]+/g, ' ').trim() || 'Imported note';
  const note = { id: `note-${Date.now()}`, title, content, pinned: false, updatedAt: Date.now() };
  state.notes.push(note); state.activeId = note.id; persist(); renderList(); renderEditor(); showToast('Markdown note imported');
  event.target.value = '';
});
document.querySelector('#previewToggle').addEventListener('click', event => { const showing = editorWrap.classList.toggle('previewing'); event.currentTarget.classList.toggle('active', showing); event.currentTarget.textContent = showing ? 'Edit' : 'Preview'; if (showing) renderPreview(); });
document.querySelector('#titleEdit').addEventListener('click', () => { els.title.focus(); els.title.select(); });
els.title.addEventListener('input', markDirty); els.content.addEventListener('input', () => { markDirty(); updateCounts(); });
document.querySelectorAll('[data-format]').forEach(button => button.addEventListener('click', () => insertFormat(button.dataset.format)));
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'n') { event.preventDefault(); createNote(); }
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f') { event.preventDefault(); els.search.focus(); }
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') { event.preventDefault(); flushSave(); showToast('Saved locally'); }
  if ((event.metaKey || event.ctrlKey) && event.key === 'ArrowDown') { event.preventDefault(); moveNote(1); }
  if ((event.metaKey || event.ctrlKey) && event.key === 'ArrowUp') { event.preventDefault(); moveNote(-1); }
  if (event.key === 'Escape' && document.activeElement === els.search) { els.search.value = ''; renderList(); els.content.focus(); }
  if (event.key === 'Escape' && editorWrap.classList.contains('previewing')) { document.querySelector('#previewToggle').click(); }
});
window.addEventListener('beforeunload', flushSave);

applyTheme(initialTheme); renderList(); renderEditor();
