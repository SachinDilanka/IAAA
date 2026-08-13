// HTML5 Geolocation API & Location Classification Bridge

document.addEventListener('DOMContentLoaded', () => {
    const detectBtn = document.getElementById('detect-location-btn');
    const resultBox = document.getElementById('detection-result-box');
    const statusText = document.getElementById('geo-status-text');

    if (detectBtn) {
        detectBtn.addEventListener('click', () => {
            if (!navigator.geolocation) {
                showResult('Geolocation is not supported by your browser. Please select your location manually below.', 'warning');
                return;
            }

            detectBtn.disabled = true;
            detectBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Locating place nearby...';
            if (statusText) statusText.innerText = 'Detecting your coordinates and matching nearby places...';

            navigator.geolocation.getCurrentPosition(
                async (position) => {
                    const lat = position.coords.latitude;
                    const lon = position.coords.longitude;
                    
                    try {
                        const response = await fetch('/api/detect-location', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ lat, lon })
                        });
                        const data = await response.json();

                        if (data.success && data.detected_slug) {
                            showResult(`Location detected: <strong>${data.poi_name}</strong>. Redirecting...`, 'success');
                            setTimeout(() => {
                                window.location.href = `/location/${data.detected_slug}`;
                            }, 1200);
                        } else {
                            showResult(`Detected coordinates near <strong>${data.poi_name || 'your area'}</strong>. Selected general messages.`, 'info');
                            setTimeout(() => {
                                window.location.href = `/location/${data.detected_slug || 'other'}`;
                            }, 1500);
                        }
                    } catch (err) {
                        console.error('Location API call failed', err);
                        showResult('Unable to reach location services. Please choose your location manually.', 'warning');
                        resetButton();
                    }
                },
                (error) => {
                    console.warn('Geolocation permission error:', error.message);
                    let msg = 'Location access denied or unavailable. Please choose your place type manually below.';
                    if (error.code === error.TIMEOUT) msg = 'Location detection timed out. Please select your place type below.';
                    showResult(msg, 'warning');
                    resetButton();
                },
                { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 }
            );
        });
    }

    function showResult(message, type) {
        if (!resultBox) return;
        resultBox.className = `detection-result detection-${type}`;
        resultBox.innerHTML = `<p><i class="fa-solid fa-circle-info"></i> ${message}</p>`;
        resultBox.classList.remove('hidden');
    }

    function resetButton() {
        if (!detectBtn) return;
        detectBtn.disabled = false;
        detectBtn.innerHTML = '<i class="fa-solid fa-compass"></i> Detect My Current Location';
    }
});
