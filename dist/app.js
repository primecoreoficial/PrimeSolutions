const config = window.PRIMECORE || {};
document.getElementById('year').textContent = new Date().getFullYear();
if (/^\d{10,15}$/.test(config.whatsapp)) {
  const link = document.getElementById('whatsapp');
  link.href = 'https://wa.me/' + config.whatsapp + '?text=' + encodeURIComponent('Olá! Gostaria de conhecer as soluções da PrimeCore.');
  link.target = '_blank'; link.rel = 'noopener noreferrer'; link.removeAttribute('aria-disabled');
  document.getElementById('whatsapp-description').textContent = 'Converse com a PrimeCore';
}
if (config.videoUrl) {
  const video = document.createElement('video');
  const placeholder = document.getElementById('video-slot');
  video.controls = true;
  video.playsInline = true;
  video.preload = 'metadata';
  video.setAttribute('aria-label', 'Apresentação da PrimeCore');
  video.addEventListener('loadedmetadata', () => {
    if (placeholder.isConnected) placeholder.replaceWith(video);
  });
  video.addEventListener('error', () => {
    if (video.isConnected) video.replaceWith(placeholder);
  });
  video.src = config.videoUrl;
}
