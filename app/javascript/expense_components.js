// Expense upload components — Alpine.data registrations
// Extracted from expense_uploads/new.html.erb and show.html.erb

// File drop zone — drag-and-drop file upload with preview
function registerFileDrop() {
  Alpine.data('fileDrop', () => ({
    dragging: false,
    fileName: null,
    fileSize: null,
    handleDrop(e) {
      this.dragging = false;
      const file = e.dataTransfer.files[0];
      if (file) this.setFile(file);
    },
    handleSelect(e) {
      const file = e.target.files[0];
      if (file) this.setFile(file);
    },
    setFile(file) {
      this.fileName = file.name;
      this.fileSize = this.formatSize(file.size);
      const dt = new DataTransfer();
      dt.items.add(file);
      this.$refs.fileInput.files = dt.files;
    },
    clear() {
      this.fileName = null;
      this.fileSize = null;
      this.$refs.fileInput.value = '';
    },
    formatSize(bytes) {
      if (bytes < 1024) return bytes + ' B';
      if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
      return (bytes / 1048576).toFixed(1) + ' MB';
    }
  }));
}

// Evaluation progress — real-time ActionCable progress tracker
function registerEvaluationProgress() {
  Alpine.data('evaluationProgress', (uploadSlug, initial = {}) => ({
    batch: 0,
    totalBatches: 0,
    processed: initial.processed || 0,
    total: initial.total || 0,
    percent: (initial.total > 0) ? (initial.processed / initial.total) * 100 : 0,
    error: null,
    subscription: null,

    get statusText() {
      if (this.total === 0) return 'Starting...'
      if (this.totalBatches > 0) return `Batch ${this.batch} of ${this.totalBatches} — ${this.processed} / ${this.total} transactions`
      return `${this.processed} / ${this.total} transactions evaluated`
    },

    get percentText() {
      return Math.round(this.percent) + '%'
    },

    init() {
      const waitForCable = () => {
        if (window.cable) {
          this.subscribe(uploadSlug)
        } else {
          setTimeout(waitForCable, 100)
        }
      }
      waitForCable()
    },

    subscribe(slug) {
      const component = this
      this.subscription = window.cable.subscriptions.create(
        { channel: 'ExpenseEvaluationChannel', upload_slug: slug },
        {
          received(data) {
            if (data.type === 'progress') {
              component.batch = data.batch
              component.totalBatches = data.total_batches
              component.processed = data.processed
              component.total = data.total
              component.percent = data.total > 0 ? (data.processed / data.total) * 100 : 0
            } else if (data.type === 'complete') {
              component.percent = 100
              setTimeout(() => window.location.reload(), 500)
            } else if (data.type === 'error') {
              component.error = data.message
              setTimeout(() => window.location.reload(), 3000)
            }
          }
        }
      )
    },

    destroy() {
      if (this.subscription) this.subscription.unsubscribe()
    }
  }))
}

// Register components — must run before Alpine.start()
function registerExpenseComponents() {
  registerFileDrop();
  registerEvaluationProgress();
}

// Both alpine:init and importmap modules load async — handle any ordering
document.addEventListener('alpine:init', registerExpenseComponents);
// If alpine:init already fired, Alpine global exists — register directly
if (window.Alpine) { registerExpenseComponents(); }
