// open-farm wiki · 审阅站交互：全局搜索层、列表/表格切换、表格排序、回顶部。
// 依赖同目录的 search-index.js（window.WIKI_INDEX / window.WIKI_KINDS）。
(function () {
  const layer = document.querySelector('.searchlayer');
  const q = document.getElementById('q');
  const res = document.getElementById('sres');
  const INDEX = window.WIKI_INDEX || [];
  const KINDS = window.WIKI_KINDS || {};
  const detailUrl = e => 'd_' + e.k + '_' + e.i + '.html';

  function openSearch() {
    layer.hidden = false;
    q.value = '';
    render('');
    setTimeout(() => q.focus(), 30);
  }
  function closeSearch() { layer.hidden = true; }

  function row(e) {
    return '<a class="row" href="' + detailUrl(e) + '"><div class="row-main">' +
      '<span class="row-name">' + escapeHtml(e.n) + '</span>' +
      '<span class="row-sub">' + escapeHtml(KINDS[e.k] || e.k) + ' · ' + escapeHtml(e.i) + '</span>' +
      '</div></a>';
  }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function render(term) {
    const t = term.trim().toLowerCase();
    const hits = t
      ? INDEX.filter(e => e.n.toLowerCase().includes(t) || e.i.includes(t) || (KINDS[e.k] || '').includes(t))
      : INDEX.slice(0, 40);
    res.innerHTML = hits.length
      ? hits.slice(0, 80).map(row).join('')
      : '<p class="dim">没有匹配</p>';
  }

  document.querySelectorAll('.search-open, .tab[data-tab="search"]').forEach(el =>
    el.addEventListener('click', e => { e.preventDefault(); openSearch(); }));
  const closeBtn = document.querySelector('.search-close');
  if (closeBtn) closeBtn.addEventListener('click', closeSearch);
  if (q) q.addEventListener('input', () => render(q.value));
  document.addEventListener('keydown', e => {
    if (layer.hidden) {
      if (e.key === '/' && document.activeElement.tagName !== 'INPUT') { e.preventDefault(); openSearch(); }
    } else if (e.key === 'Escape') {
      closeSearch();
    }
  });

  // 列表 / 表格切换：表格由列表行现场生成，避免重复维护两份数据。
  document.querySelectorAll('.segmented').forEach(seg => {
    const section = seg.closest('main');
    const list = section.querySelector('.list, .dgroups');
    const wrap = section.querySelector('.tblwrap');
    if (!list || !wrap) return;
    seg.addEventListener('click', e => {
      const btn = e.target.closest('button');
      if (!btn) return;
      const table = btn.dataset.mode === 'table';
      seg.querySelectorAll('button').forEach(b => b.classList.toggle('on', b === btn));
      list.hidden = table;
      wrap.hidden = !table;
      try { localStorage.setItem('wiki-view-' + seg.dataset.kind, btn.dataset.mode); } catch (err) {}
    });
    try {
      if (localStorage.getItem('wiki-view-' + seg.dataset.kind) === 'table') {
        seg.querySelector('button[data-mode="table"]').click();
      }
    } catch (err) {}
  });

  // 表头点击排序（数值列按数值，其余按中文）。
  function sortVal(a, b) {
    const na = parseFloat(a.replace(/[^\d.\-]/g, ''));
    const nb = parseFloat(b.replace(/[^\d.\-]/g, ''));
    if (!isNaN(na) && !isNaN(nb)) return na - nb;
    return a.localeCompare(b, 'zh');
  }
  document.querySelectorAll('.data-table').forEach(table => {
    table.querySelectorAll('th').forEach((th, idx) => {
      th.addEventListener('click', () => {
        const dir = th.dataset.dir === 'asc' ? -1 : 1;
        table.querySelectorAll('th').forEach(o => { delete o.dataset.dir; o.classList.remove('sorted-asc', 'sorted-desc'); });
        th.dataset.dir = dir === 1 ? 'asc' : 'desc';
        th.classList.add(dir === 1 ? 'sorted-asc' : 'sorted-desc');
        const body = table.tBodies[0];
        [...body.rows].sort((a, b) => dir * sortVal(a.cells[idx].textContent, b.cells[idx].textContent))
          .forEach(r => body.appendChild(r));
      });
    });
  });

  // 回顶部。
  const top = document.getElementById('totop');
  if (top) {
    top.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
    addEventListener('scroll', () => top.classList.toggle('show', scrollY > 500));
  }
})();
