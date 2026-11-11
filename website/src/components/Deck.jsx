import { useGSAP } from '@gsap/react'
import gsap from 'gsap'
import { useRef } from 'react'
import { Bell, Coffee, Scale, ScanLine, ShieldCheck, WifiOff } from 'lucide-react'
import { features } from '../content.js'

const icons = { 'wifi-off': WifiOff, scale: Scale, scan: ScanLine, shield: ShieldCheck, bell: Bell, coffee: Coffee }
const WIDE = '(min-width: 900px) and (prefers-reduced-motion: no-preference)'

export default function Deck() {
  const root = useRef(null)

  useGSAP(
    () => {
      const mm = gsap.matchMedia()
      mm.add(WIDE, () => {
        const grid = root.current.querySelector('.deck')
        const cards = gsap.utils.toArray('.card', grid)
        // Start as one stacked pile in the middle (like the app's card deck), then deal out.
        const offset = (el) => {
          const g = grid.getBoundingClientRect()
          const r = el.getBoundingClientRect()
          return { x: g.left + g.width / 2 - (r.left + r.width / 2), y: g.top + g.height / 2 - (r.top + r.height / 2) }
        }
        gsap.fromTo(
          cards,
          {
            x: (i, el) => offset(el).x,
            y: (i, el) => offset(el).y + i * -6,
            rotate: (i) => (i - 2.5) * 4,
            scale: 0.92,
          },
          {
            x: 0, y: 0, rotate: 0, scale: 1, ease: 'power2.inOut', stagger: 0.04,
            scrollTrigger: { trigger: grid, start: 'top 85%', end: 'top 25%', scrub: 0.8, invalidateOnRefresh: true },
          },
        )
      })
    },
    { scope: root },
  )

  return (
    <section id="features" ref={root} className="features">
      <header className="features__head">
        <p className="kicker"><span className="kicker__dot" />Built for the room</p>
        <h2 className="h2" data-words>Small things that make a big room <em>feel easy.</em></h2>
      </header>
      <ul className="deck">
        {features.map((f, i) => {
          const Ic = icons[f.icon]
          return (
            <li key={f.title} className={`card card--${(i % 3) + 1}`}>
              <span className="card__icon"><Ic size={24} aria-hidden="true" /></span>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
              <span className="card__corner" aria-hidden="true">{String(i + 1).padStart(2, '0')}</span>
            </li>
          )
        })}
      </ul>
    </section>
  )
}
