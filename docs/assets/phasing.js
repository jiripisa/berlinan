(() => {
  // Three loops of 7, 5 and 6 steps, like the app icon: they realign every lcm = 210 steps.
  const PATTERNS = [
    [1, 0, 1, 1, 0, 1, 0],
    [1, 0, 0, 1, 0],
    [1, 1, 0, 1, 0, 0],
  ];
  const CYCLE = 210;
  const STEP_MS = 180;
  // Texts come from the page (data-* on .machine), so each language version sets its own.
  const text = Object.assign({
    aligned: 'all three aligned',
    alignedIn: 'aligned again in {n} steps',
    play: 'Play',
    pause: 'Pause',
  }, document.querySelector('.machine').dataset);

  const lanes = [...document.querySelectorAll('.machine .lane')].map((lane, i) => {
    const box = lane.querySelector('.cells');
    return PATTERNS[i].map(on => {
      const cell = document.createElement('span');
      cell.className = on ? 'cell note' : 'cell';
      box.appendChild(cell);
      return cell;
    });
  });

  const counter = document.getElementById('counter');
  const toggle = document.getElementById('toggle');
  let step = 0;
  let timer = null;

  function render() {
    lanes.forEach(cells => cells.forEach((c, i) => c.classList.toggle('now', i === step % cells.length)));
    const left = (CYCLE - (step % CYCLE)) % CYCLE;
    counter.textContent = left === 0 ? text.aligned : text.alignedIn.replace('{n}', left);
    counter.classList.toggle('aligned', left === 0);
  }

  function play() {
    timer = setInterval(() => { step += 1; render(); }, STEP_MS);
    toggle.textContent = text.pause;
    toggle.setAttribute('aria-pressed', 'false');
  }

  function pause() {
    clearInterval(timer);
    timer = null;
    toggle.textContent = text.play;
    toggle.setAttribute('aria-pressed', 'true');
  }

  toggle.addEventListener('click', () => (timer ? pause() : play()));

  render();
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) pause();
  else play();
})();
