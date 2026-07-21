(() => {
  const search = document.getElementById('docSearch');
  const sections = [...document.querySelectorAll('main > section')];
  const links = [...document.querySelectorAll('.sidebar nav a')];
  const noResults = document.getElementById('noResults');
  const sidebar = document.getElementById('sidebar');
  const menuButton = document.getElementById('menuButton');
  const toast = document.getElementById('toast');
  let toastTimer;

  function normalizedText(section) {
    return `${section.dataset.search || ''} ${section.textContent || ''}`.toLowerCase();
  }

  function filterSections(query) {
    const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
    let visible = 0;
    for (const section of sections) {
      const haystack = normalizedText(section);
      const matches = words.every(word => haystack.includes(word));
      section.hidden = !matches;
      if (matches) visible += 1;
    }
    noResults.hidden = visible !== 0;
  }

  function setActiveLink(id) {
    links.forEach(link => link.classList.toggle('active', link.hash === `#${id}`));
  }

  const observer = new IntersectionObserver(entries => {
    const visible = entries
      .filter(entry => entry.isIntersecting && !entry.target.hidden)
      .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (visible) setActiveLink(visible.target.id);
  }, { rootMargin: '-20% 0px -65%', threshold: [0.05, 0.2, 0.5] });

  sections.forEach(section => observer.observe(section));
  search.addEventListener('input', event => filterSections(event.target.value));
  search.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      search.value = '';
      filterSections('');
      search.blur();
    }
  });

  menuButton.addEventListener('click', () => {
    const open = sidebar.classList.toggle('open');
    menuButton.setAttribute('aria-expanded', String(open));
  });

  links.forEach(link => link.addEventListener('click', () => {
    sidebar.classList.remove('open');
    menuButton.setAttribute('aria-expanded', 'false');
  }));

  function showToast(message) {
    clearTimeout(toastTimer);
    toast.textContent = message;
    toast.classList.add('show');
    toastTimer = setTimeout(() => toast.classList.remove('show'), 1800);
  }

  document.querySelectorAll('[data-copy]').forEach(button => {
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        showToast('Copied endpoint');
      } catch {
        showToast('Copy unavailable');
      }
    });
  });

  setActiveLink(location.hash.slice(1) || 'overview');
})();
