// A web port of the app's AeroShards background (lib/core/widgets/aero_shards.dart):
// graphite glass slivers drifting along three flowing ribbons, a few in brand red,
// with twinkling "+" markers. Far shards are smaller, fainter and blurred.

const SCALE = [0.45, 0.62, 0.8, 1.0, 1.3]
const ALPHA = [0.06, 0.1, 0.15, 0.22, 0.3]
const BLUR = [2.6, 1.6, 0.8, 0, 0]
const PACE = [0.35, 0.5, 0.7, 0.9, 1.15]

function rng(seed) {
  let s = seed >>> 0
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296)
}

function make(n) {
  const r = rng(121)
  return Array.from({ length: n }, () => {
    const long = 1 + r() * 1.4
    const skew = (r() - 0.5) * 0.5
    return {
      ribbon: Math.floor(r() * 3),
      depth: Math.min(4, Math.floor(Math.pow(r(), 0.8) * 5)),
      t: r(),
      lateral: r() * 2 - 1,
      size: 4 + r() * 6,
      angle: 0.12 + (r() - 0.5) * 0.7,
      spin: (r() - 0.5) * 0.12,
      poly: [[-long + skew, -0.42], [long + skew, -0.42], [long - skew, 0.42], [-long - skew, 0.42]],
      hue: r(),
    }
  }).sort((a, b) => a.depth - b.depth)
}

function ribbon(i, u, w, h, t) {
  const base = [0.18, 0.4, 0.62][i]
  const amp = [0.06, 0.08, 0.06][i]
  const f = [1.3, 1.0, 1.6][i]
  const y = base + amp * Math.sin(u * Math.PI * 2 * f + t * 0.35 + i * 1.7) + 0.03 * Math.sin(u * Math.PI * 7 + t * 0.9 + i)
  return [u * (w + 80) - 40, (y + (u - 0.5) * 0.12) * h]
}

/** Starts the field on `canvas`; returns a stop function. */
export function startShards(canvas, { count = 130, accentShare = 0.12, still = false } = {}) {
  // ?still draws one frame (for screenshots: a never-ending loop stalls headless capture).
  still = still || /[?&]still\b/.test(location.search)
  const ctx = canvas.getContext('2d')
  const shards = make(count)
  const shard = [58, 63, 74]
  const accent = [200, 16, 46]
  let w = 0, h = 0, raf = 0, time = 0, last = performance.now()
  let pointer = null

  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    w = canvas.clientWidth
    h = canvas.clientHeight
    canvas.width = w * dpr
    canvas.height = h * dpr
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  }
  const ro = new ResizeObserver(resize)
  ro.observe(canvas)
  resize()

  const onMove = (e) => {
    const b = canvas.getBoundingClientRect()
    pointer = [e.clientX - b.left, e.clientY - b.top]
  }
  const onLeave = () => (pointer = null)
  window.addEventListener('pointermove', onMove, { passive: true })
  window.addEventListener('pointerleave', onLeave)

  const markers = (t) => {
    const sp = 34
    ctx.lineWidth = 1.2
    ctx.lineCap = 'round'
    for (let y = 0; y < h / sp + 1; y++) {
      for (let x = 0; x < w / sp + 1; x++) {
        const hsh = ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
        if (hsh % 3) continue
        const ox = x * sp + (hsh % 7) - 3
        const oy = y * sp + (hsh % 5) - 2
        let near = 0
        for (let r = 0; r < 3; r++) {
          const [, ry] = ribbon(r, (ox + 40) / (w + 80), w, h, t)
          near = Math.max(near, Math.min(1, Math.max(0, 1 - Math.abs(ry - oy) / (h * 0.07))))
        }
        const tw = 0.5 + 0.5 * Math.sin(t * 1.6 + (hsh % 1000) / 160)
        const a = Math.min(0.45, 0.06 + near * 0.32 * tw)
        if (a < 0.07) continue
        ctx.strokeStyle = `rgba(${shard},${a * 0.8})`
        ctx.beginPath()
        ctx.moveTo(ox - 3, oy); ctx.lineTo(ox + 3, oy)
        ctx.moveTo(ox, oy - 3); ctx.lineTo(ox, oy + 3)
        ctx.stroke()
      }
    }
  }

  const frame = (now) => {
    time += Math.min(0.05, (now - last) / 1000)
    last = now
    const t = time
    ctx.clearRect(0, 0, w, h)
    markers(t)
    for (const s of shards) {
      const u = (s.t + t * 0.018 * PACE[s.depth]) % 1
      let [cx, cy] = ribbon(s.ribbon, u, w, h, t)
      cy += s.lateral * h * (0.012 + 0.007 * s.depth) + Math.sin(t * 0.8 + s.t * 20) * 6
      if (pointer) {
        const dx = cx - pointer[0], dy = cy - pointer[1], d = Math.hypot(dx, dy)
        if (d < 110 && d > 0.1) {
          const push = (110 - d) * 0.55 * (0.4 + s.depth * 0.15)
          cx += (dx / d) * push
          cy += (dy / d) * push
        }
      }
      const k = s.size * SCALE[s.depth]
      const a = s.angle + t * s.spin
      const cos = Math.cos(a), sin = Math.sin(a)
      ctx.beginPath()
      s.poly.forEach(([px, py], i) => {
        const x = cx + (px * cos - py * sin) * k
        const y = cy + (px * sin + py * cos) * k
        i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
      })
      ctx.closePath()
      const al = ALPHA[s.depth]
      const tint = s.hue < accentShare ? accent : shard
      const g = ctx.createLinearGradient(cx - k, cy - k, cx + k, cy + k)
      g.addColorStop(0, `rgba(255,255,255,${al * 0.9})`)
      g.addColorStop(1, `rgba(${tint},${al})`)
      ctx.filter = BLUR[s.depth] ? `blur(${BLUR[s.depth]}px)` : 'none'
      ctx.fillStyle = g
      ctx.fill()
      ctx.filter = 'none'
      if (s.depth >= 3) {
        ctx.lineWidth = s.depth === 4 ? 1.1 : 0.8
        ctx.strokeStyle = 'rgba(255,255,255,0.75)'
        ctx.stroke()
      }
    }
    if (!still) raf = requestAnimationFrame(frame)
  }
  raf = requestAnimationFrame(frame)

  return () => {
    cancelAnimationFrame(raf)
    ro.disconnect()
    window.removeEventListener('pointermove', onMove)
    window.removeEventListener('pointerleave', onLeave)
  }
}
