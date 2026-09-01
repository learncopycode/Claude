// Small UI helpers shared across modules.

// Promise-based confirm dialog. Native confirm() is blocked in sandboxed
// iframes (like the Claude artifact viewer) and ugly everywhere else.
export function confirmDialog(message, { confirmLabel = 'Delete' } = {}) {
  return new Promise(resolve => {
    const modal = document.getElementById('modal-confirm');
    document.getElementById('confirm-message').textContent = message;
    const okBtn = document.getElementById('btn-confirm-ok');
    okBtn.textContent = confirmLabel;
    modal.classList.remove('hidden');

    const done = answer => {
      modal.classList.add('hidden');
      okBtn.removeEventListener('click', onOk);
      cancelBtn.removeEventListener('click', onCancel);
      modal.removeEventListener('pointerdown', onBackdrop);
      resolve(answer);
    };
    const onOk = () => done(true);
    const onCancel = () => done(false);
    const onBackdrop = ev => { if (ev.target === modal) done(false); };
    const cancelBtn = document.getElementById('btn-confirm-cancel');
    okBtn.addEventListener('click', onOk);
    cancelBtn.addEventListener('click', onCancel);
    modal.addEventListener('pointerdown', onBackdrop);
  });
}
