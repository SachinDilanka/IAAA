/* main.js – Home Page: Detect My Location button feedback */

document.addEventListener('DOMContentLoaded', () => {
    const detectBtn = document.getElementById('detect-btn');
    const feedbackBox = document.getElementById('detect-feedback');

    if (!detectBtn) return;

    detectBtn.addEventListener('click', () => {
        if (!navigator.geolocation) {
            showFeedback('Geolocation is not supported by your browser. Please select your location manually below.');
            return;
        }

        detectBtn.disabled = true;
        detectBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Detecting location…';

        navigator.geolocation.getCurrentPosition(
            async (position) => {
                try {
                    const res = await fetch('/api/detect-location', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            lat: position.coords.latitude,
                            lon: position.coords.longitude
                        })
                    });
                    const data = await res.json();
                    const slug = data.detected_slug || 'other';
                    const name = data.poi_name || 'your area';
                    showFeedback(`Detected: <strong>${name}</strong>. Redirecting…`);
                    setTimeout(() => { window.location.href = `/location/${slug}`; }, 1200);
                } catch (err) {
                    showFeedback('Could not reach location services. Please select manually.');
                    resetBtn();
                }
            },
            (err) => {
                showFeedback('Location access denied. Please select your location manually below.');
                resetBtn();
            },
            { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 }
        );
    });

    function showFeedback(html) {
        feedbackBox.innerHTML = `<i class="fa-solid fa-circle-info"></i> ${html}`;
        feedbackBox.style.display = 'block';
    }

    function resetBtn() {
        detectBtn.disabled = false;
        detectBtn.innerHTML = '<i class="fa-solid fa-compass"></i> Detect My Location';
    }
});
