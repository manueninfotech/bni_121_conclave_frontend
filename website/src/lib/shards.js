// A web port of the app's AeroShards background (lib/core/widgets/aero_shards.dart):
// graphite glass slivers drifting along three flowing ribbons, a few in brand red,
// with twinkling "+" markers. Far shards are smaller, fainter and blurred.
//
// Built to stay at 60fps: each shard (its gradient, blur and edge) is drawn once
// into a small sprite, and every frame only moves and rotates those sprites. The
// marker lattice is cached and its ribbon maths runs once per column. The loop
// pauses while the canvas is off-screen or the tab is hidden.

const SCALE = [0.45, 0.62, 0.8, 1.0, 1.3]
const ALPHA = [0.06, 0.1, 0.15, 0.22, 0.3]
const BLUR = [2.6, 1.6, 0.8, 0, 0]
const PACE = [0.35, 0.5, 0.7, 0.9, 1.15]
const SHARD = '58,63,74'
const ACCENT = '200,16,46'

function rng(seed) {
  let s = seed >>> 0
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296)
}

function ribbonY(i, u, h, t) {
  const base = [0.18, 0.4, 0.62][i]
  const amp = [0.06, 0.08, 0.06][i]
  const f = [1.3, 1.0, 1.6][i]
  const y = base + amp * Math.sin(u * Math.PI * 2 * f + t * 0.35 + i * 1.7) + 0.03 * Math.sin(u * Math.PI * 7 + t * 0.9 + i)
  return (y + (u - 0.5) * 0.12) * h
}

/** Draws one shard, unrotated, into its own small canvas at device resolution. */
function sprite(s, dpr, accentShare) {
  const k = s.size * SCALE[s.depth]
  const blur = BLUR[s.depth]
  const pad = blur * 3 + 2
  const halfW = (s.long + Math.abs(s.skew)) * k + pad
  const halfH = 0.42 * k + pad
  const c = document.createElement('canvas')
  c.width = Math.ceil(halfW * 2 * dpr)
  c.height = Math.ceil(halfH * 2 * dpr)
  const g = c.getContext('2d')
  g.scale(dpr, dpr)
  g.translate(halfW, halfH)
  g.beginPath()
  g.moveTo((-s.long + s.skew) * k, -0.42 * k)
  g.lineTo((s.long + s.skew) * k, -0.42 * k)
  g.lineTo((s.long - s.skew) * k, 0.42 * k)
  g.lineTo((-s.long - s.skew) * k, 0.42 * k)
  g.closePath()
  const a = ALPHA[s.depth]
  const tint = s.hue < accentShare ? ACCENT : SHARD
  const grad = g.createLinearGradient(-k, -k, k, k)
  grad.addColorStop(0, `rgba(255,255,255,${a * 0.9})`)
  grad.addColorStop(1, `rgba(${tint},${a})`)
  if (blur) g.filter = `blur(${blur}px)`
  g.fillStyle = grad
  g.fill()
  g.filter = 'none'
  if (s.depth >= 3) {
    g.lineWidth = s.depth === 4 ? 1.1 : 0.8
    g.strokeStyle = 'rgba(255,255,255,0.75)'
    g.stroke()
  }
  return { img: c, w: halfW * 2, h: halfH * 2 }
}

function make(n) {
  const r = rng(121)
  return Array.from({ length: n }, () => ({
    long: 1 + r() * 1.4,
    skew: (r() - 0.5) * 0.5,
    ribbon: Math.floor(r() * 3),
    depth: Math.min(4, Math.floor(Math.pow(r(), 0.8) * 5)),
    t: r(),
    lateral: r() * 2 - 1,
    size: 4 + r() * 6,
    angle: 0.12 + (r() - 0.5) * 0.7,
    spin: (r() - 0.5) * 0.12,
    hue: r(),
  })).sort((a, b) => a.depth - b.depth)
}

/** Starts the field on `canvas`; returns a stop function. */
export function startShards(canvas, { count = 130, accentShare = 0.12, still = false } = {}) {
  // ?still draws one frame (for screenshots: a never-ending loop stalls headless capture).
  still = still || /[?&]still\b/.test(location.search)
  const ctx = canvas.getContext('2d', { alpha: true })
  const dpr = Math.min(window.devicePixelRatio || 1, 1.5)
  const small = window.matchMedia('(max-width: 760px)').matches
  const shards = make(small ? Math.round(count * 0.55) : count)
  const sprites = shards.map((s) => sprite(s, dpr, accentShare))

  let w = 0, h = 0, raf = 0, time = 0, last = 0
  let pointer = null
  let visible = true
  let lattice = [] // [{x, y, col, phase}]
  let cols = 0

  const resize = () => {
    w = canvas.clientWidth
    h = canvas.clientHeight
    canvas.width = Math.round(w * dpr)
    canvas.height = Math.round(h * dpr)
    const sp = 34
    cols = Math.ceil(w / sp) + 1
    lattice = []
    for (let y = 0; y < h / sp + 1; y++) {
      for (let x = 0; x < cols; x++) {
        const hsh = ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
        if (hsh % 3) continue
        lattice.push({ x: x * sp + (hsh % 7) - 3, y: y * sp + (hsh % 5) - 2, col: x, phase: (hsh % 1000) / 160 })
      }
    }
    if (still) draw()
  }

  const colY = new Float32Array(3 * 64)
  const drawMarkers = (t) => {
    // Ribbon heights depend only on x, so work them out once per column.
    for (let c = 0; c < cols && c < 64; c++) {
      const u = (c * 34 + 40) / (w + 80)
      for (let r = 0; r < 3; r++) colY[c * 3 + r] = ribbonY(r, u, h, t)
    }
    const band = h * 0.07
    ctx.lineWidth = 1.2
    ctx.lineCap = 'round'
    ctx.strokeStyle = `rgb(${SHARD})`
    for (const m of lattice) {
      const c = Math.min(m.col, 63) * 3
      const d = Math.min(Math.abs(colY[c] - m.y), Math.abs(colY[c + 1] - m.y), Math.abs(colY[c + 2] - m.y))
      const near = d < band ? 1 - d / band : 0
      if (!near) continue
      const a = Math.min(0.45, 0.06 + near * 0.32 * (0.5 + 0.5 * Math.sin(t * 1.6 + m.phase)))
      if (a < 0.07) continue
      ctx.globalAlpha = a * 0.8
      ctx.beginPath()
      ctx.moveTo(m.x - 3, m.y); ctx.lineTo(m.x + 3, m.y)
      ctx.moveTo(m.x, m.y - 3); ctx.lineTo(m.x, m.y + 3)
      ctx.stroke()
    }
    ctx.globalAlpha = 1
  }

  function draw() {
    const t = time
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, w, h)
    drawMarkers(t)
    for (let i = 0; i < shards.length; i++) {
      const s = shards[i]
      const u = (s.t + t * 0.018 * PACE[s.depth]) % 1
      let cx = u * (w + 80) - 40
      let cy = ribbonY(s.ribbon, u, h, t) + s.lateral * h * (0.012 + 0.007 * s.depth) + Math.sin(t * 0.8 + s.t * 20) * 6
      if (pointer) {
        const dx = cx - pointer[0], dy = cy - pointer[1], d = Math.hypot(dx, dy)
        if (d < 110 && d > 0.1) {
          const push = (110 - d) * 0.55 * (0.4 + s.depth * 0.15)
          cx += (dx / d) * push
          cy += (dy / d) * push
        }
      }
      const a = s.angle + t * s.spin
      const cos = Math.cos(a) * dpr, sin = Math.sin(a) * dpr
      const sp = sprites[i]
      ctx.setTransform(cos, sin, -sin, cos, cx * dpr, cy * dpr)
      ctx.drawImage(sp.img, -sp.w / 2, -sp.h / 2, sp.w, sp.h)
    }
  }

  const frame = (now) => {
    raf = 0
    if (!visible || document.hidden) return
    time += Math.min(0.05, last ? (now - last) / 1000 : 0)
    last = now
    draw()
    raf = requestAnimationFrame(frame)
  }
  const start = () => {
    if (still || raf || !visible || document.hidden) return
    last = 0
    raf = requestAnimationFrame(frame)
  }

  const ro = new ResizeObserver(resize)
  ro.observe(canvas)
  resize()

  // Only animate while on screen and the tab is in front.
  const io = new IntersectionObserver(([e]) => {
    visible = e.isIntersecting
    start()
  })
  io.observe(canvas)
  const onVis = () => start()
  document.addEventListener('visibilitychange', onVis)

  const onMove = (e) => {
    const b = canvas.getBoundingClientRect()
    pointer = [e.clientX - b.left, e.clientY - b.top]
  }
  const onLeave = () => (pointer = null)
  window.addEventListener('pointermove', onMove, { passive: true })
  document.addEventListener('pointerleave', onLeave)

  if (still) draw()
  else start()

  return () => {
    cancelAnimationFrame(raf)
    ro.disconnect()
    io.disconnect()
    document.removeEventListener('visibilitychange', onVis)
    window.removeEventListener('pointermove', onMove)
    document.removeEventListener('pointerleave', onLeave)
  }
}
