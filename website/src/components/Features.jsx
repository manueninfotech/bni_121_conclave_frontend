import { Bell, Coffee, Scale, ScanLine, ShieldCheck, WifiOff } from 'lucide-react'
import { features } from '../content.js'
import { asset } from '../lib/asset.js'
import Phone from './Phone.jsx'

const icons = { 'wifi-off': WifiOff, scale: Scale, scan: ScanLine, shield: ShieldCheck, bell: Bell, coffee: Coffee }

// A soft light follows the pointer across each tile.
const spot = (e) => {
  const r = e.currentTarget.getBoundingClientRect()
  e.currentTarget.style.setProperty('--x', `${e.clientX - r.left}px`)
  e.currentTarget.style.setProperty('--y', `${e.clientY - r.top}px`)
}

export default function Features() {
  return (
    <section id="features" className="features">
      <div className="features__dots" aria-hidden="true" />
      <div className="bento">
        <div className="tile tile--lead" data-reveal>
          <img className="tile__mark" src={asset('brand/mark-white.png')} alt="" aria-hidden="true" />
          <p className="eyebrow eyebrow--light"><i />Built for the room</p>
          <h2 className="h1" data-split>Small things that make a big room <span className="grad--light">feel easy.</span></h2>
          <p className="tile__text">
            Conclaves bring dozens of business owners into one hall for a few fast rounds. 1-2-1 Connect handles the logistics, so
            every minute goes to the people in front of you.
          </p>
        </div>
        <div className="tile tile--shots" data-reveal>
          <Phone shot="people" alt="People you met, ready to save" className="tile__phone tile__phone--a" />
          <Phone shot="card" alt="Your contact card as a QR code" className="tile__phone tile__phone--b" />
        </div>
        <ul className="feat-grid" data-reveal-group>
          {features.map((f, i) => {
            const Ic = icons[f.icon]
            return (
              <li key={f.title}>
                <article className="feat" onPointerMove={spot}>
                  <span className="feat__no" aria-hidden="true">{String(i + 1).padStart(2, '0')}</span>
                  <span className="feat__icon"><Ic size={24} aria-hidden="true" /></span>
                  <h3>{f.title}</h3>
                  <p>{f.text}</p>
                </article>
              </li>
            )
          })}
        </ul>
      </div>
    </section>
  )
}
