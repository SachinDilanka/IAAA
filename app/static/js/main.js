// Main JavaScript for Accessible Communication App - Home Page

document.addEventListener('DOMContentLoaded', () => {
    const detectBtn = document.getElementById('detect-location-btn');
    const feedbackBox = document.getElementById('detection-feedback');

    if (detectBtn) {
        detectBtn.addEventListener('click', () => {
            if (feedbackBox) {
                feedbackBox.style.display = 'block';
                feedbackBox.setAttribute('aria-live', 'polite');
                feedbackBox.innerHTML = '<i class="fa-solid fa-circle-info"></i> Automatic location detection is requested. (Note: Geolocation integration will be enabled in the next stage).';
            }
        });
    }
});
