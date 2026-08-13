/* location.js – Location Dashboard interactions */

document.addEventListener('DOMContentLoaded', () => {

    // ── Custom Message Modal ─────────────────────────────────────
    const modal       = document.getElementById('custom-modal');
    const openBtns    = document.querySelectorAll('#open-custom-btn, .open-custom-trigger');
    const closeBtn    = document.getElementById('close-modal-btn');

    openBtns.forEach(btn => btn.addEventListener('click', () => {
        modal.classList.remove('hidden');
        document.getElementById('custom-text')?.focus();
    }));

    closeBtn?.addEventListener('click', () => modal.classList.add('hidden'));

    modal?.addEventListener('click', e => {
        if (e.target === modal) modal.classList.add('hidden');
    });

    // ── Fill-in Slot (e.g. "I need this item: ___") ─────────────
    document.querySelectorAll('.show-slot-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const template  = btn.dataset.template;
            const inputElem = document.getElementById(btn.dataset.input);
            const icon      = btn.dataset.icon || 'fa-comment';
            const location  = btn.dataset.location || 'other';
            const slotVal   = inputElem?.value.trim() || '___';
            const final     = template.replace('{slot}', slotVal);
            window.location.href = `/show?text=${encodeURIComponent(final)}&icon=${encodeURIComponent(icon)}&location=${encodeURIComponent(location)}`;
        });
    });

    // ── Category Chip Filter ─────────────────────────────────────
    const chips    = document.querySelectorAll('.chip');
    const groups   = document.querySelectorAll('.cat-group');

    chips.forEach(chip => {
        chip.addEventListener('click', e => {
            e.preventDefault();
            const cat = chip.dataset.category;
            chips.forEach(c => c.classList.remove('active'));
            chip.classList.add('active');

            groups.forEach(g => {
                g.style.display = (cat === 'all' || g.dataset.cat === cat) ? 'block' : 'none';
            });
        });
    });
});
