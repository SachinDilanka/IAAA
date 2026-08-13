// UI Interaction, Contrast, Font Sizing, Modals, and Slot Filling

document.addEventListener('DOMContentLoaded', () => {
    // 1. High Contrast Theme Management
    const contrastBtn = document.getElementById('contrast-toggle-btn');
    const htmlElem = document.documentElement;
    
    // Restore saved contrast preference
    const savedTheme = localStorage.getItem('assistcomm_theme');
    if (savedTheme === 'high-contrast') {
        htmlElem.setAttribute('data-theme', 'high-contrast');
    }

    if (contrastBtn) {
        contrastBtn.addEventListener('click', () => {
            const currentTheme = htmlElem.getAttribute('data-theme');
            const newTheme = currentTheme === 'high-contrast' ? 'light' : 'high-contrast';
            htmlElem.setAttribute('data-theme', newTheme);
            localStorage.setItem('assistcomm_theme', newTheme);
        });
    }

    // 2. Dynamic Text Size Adjuster
    const fontDecreaseBtn = document.getElementById('font-decrease-btn');
    const fontIncreaseBtn = document.getElementById('font-increase-btn');
    let currentFontSize = parseInt(localStorage.getItem('assistcomm_font_size')) || 18;

    function applyFontSize(size) {
        document.body.style.fontSize = `${size}px`;
        localStorage.setItem('assistcomm_font_size', size);
    }

    if (currentFontSize !== 18) applyFontSize(currentFontSize);

    if (fontIncreaseBtn && fontDecreaseBtn) {
        fontIncreaseBtn.addEventListener('click', () => {
            if (currentFontSize < 28) {
                currentFontSize += 2;
                applyFontSize(currentFontSize);
            }
        });
        fontDecreaseBtn.addEventListener('click', () => {
            if (currentFontSize > 14) {
                currentFontSize -= 2;
                applyFontSize(currentFontSize);
            }
        });
    }

    // 3. Custom Message Modal Controls
    const modal = document.getElementById('custom-msg-modal');
    const openModalBtns = document.querySelectorAll('#open-custom-msg-btn, #quick-custom-btn, .trigger-custom-modal-btn');
    const closeModalBtn = document.getElementById('close-modal-btn');

    if (modal) {
        openModalBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                modal.classList.remove('hidden');
                const textarea = document.getElementById('custom-text-input');
                if (textarea) textarea.focus();
            });
        });

        if (closeModalBtn) {
            closeModalBtn.addEventListener('click', () => {
                modal.classList.add('hidden');
            });
        }

        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.add('hidden');
            }
        });
    }

    // 4. Fill-in Prompt (Slot Message) Card Buttons
    const slotCardBtns = document.querySelectorAll('.show-slot-card-btn');
    slotCardBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const template = btn.dataset.template;
            const inputId = btn.dataset.inputId;
            const icon = btn.dataset.icon || 'fa-comment';
            const location = btn.dataset.location || 'other';

            const inputElem = document.getElementById(inputId);
            const userVal = inputElem ? inputElem.value.trim() : '';

            let finalMessage = template;
            if (template.includes('{slot}')) {
                finalMessage = template.replace('{slot}', userVal || '___');
            }

            const showUrl = `/show?text=${encodeURIComponent(finalMessage)}&icon=${encodeURIComponent(icon)}&location=${encodeURIComponent(location)}`;
            window.location.href = showUrl;
        });
    });

    // 5. Category Chips Filter Navigation
    const categoryChips = document.querySelectorAll('.chip-link');
    const categorySections = document.querySelectorAll('.category-section-group');

    if (categoryChips.length > 0) {
        categoryChips.forEach(chip => {
            chip.addEventListener('click', (e) => {
                const targetCategory = chip.dataset.category;
                
                categoryChips.forEach(c => c.classList.remove('active'));
                chip.classList.add('active');

                if (targetCategory === 'all') {
                    categorySections.forEach(sec => sec.style.display = 'block');
                } else {
                    categorySections.forEach(sec => {
                        if (sec.dataset.categorySlug === targetCategory) {
                            sec.style.display = 'block';
                        } else {
                            sec.style.display = 'none';
                        }
                    });
                }
            });
        });
    }
});
