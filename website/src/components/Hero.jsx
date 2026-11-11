import { useEffect, useRef, useState } from 'react'
import { useGSAP } from '@gsap/react'
import gsap from 'gsap'
import { app, facts, seats } from '../content.js'
import { reducedMotion } from '../lib/motion.js'
import { startShards } from '../lib/shards.js'
import Phone from './Phone.jsx'
import Stores from './Stores.jsx'

// Seats around the phone, as angles on an ellipse (degrees, 0 = right).
const ANGLES = [212, 180, 148, 328, 0, 32]
const TURN_MS = 2200

function Seat({ s, angle, speaking, order }) {
  const rad = (angle * Math.PI) / 180
  return (
    <div
      className={`seat ${speaking ? 'is-speaking' : ''}`}
      style={{ '--x': `${50 + Math.cos(rad) * 44}%`, '--y': `${54 + Math.sin(rad) * 30}%` }}
    >
      <span className="seat__avatar">
        {s.initial}
        <svg className="seat__ring" viewBox="0 0 56 56" aria-hidden="true">
          <circle cx="28" cy="28" r="26" />
        </svg>
      </span>
      <span className="seat__text">
        <strong>{s.name}</strong>
        <small>{speaking ? 'Speaking now' : `#${order} · ${s.trade}`}</small>
      </span>
    </div>
  )
}

export default function Hero() {
  const root = useRef(null)
  const canvas = useRef(null)
  const [speaker, setSpeaker] = useState(0)

  useEffect(() => startShards(canvas.current, { still: reducedMotion() }), [])

  // The speaking light passes round the table, like a real round.
  useEffect(() => {
    if (reducedMotion()) return
    const id = setInterval(() => setSpeaker((i) => (i + 1) % seats.length), TURN_MS)
    return () => clearInterval(id)
  }, [])

  useGSAP(
    () => {
      if (reducedMotion()) return
      gsap.from('.table__phone', { y: 160, autoAlpha: 0, duration: 1.3, delay: 0.35, ease: 'expo.out' })
      gsap.from('.table__ring', { scale: 0.6, autoAlpha: 0, duration: 1.2, delay: 0.5, ease: 'expo.out' })
      gsap.from('.seat', { scale: 0.4, autoAlpha: 0, duration: 0.8, stagger: 0.07, delay: 0.8, ease: 'back.out(1.8)' })
      gsap.to('.table', {
        yPercent: -6,
        ease: 'none',
        scrollTrigger: { trigger: root.current, start: 'top top', end: 'bottom top', scrub: true },
      })
    },
    { scope: root },
  )

  return (
    <section id="top" ref={root} className="hero">
      <canvas ref={canvas} className="hero__shards" aria-hidden="true" />
      <div className="hero__fade" aria-hidden="true" />

      <div className="hero__copy">
        <p className="kicker" data-rise data-now>
          <span className="kicker__dot" />For BNI 1-2-1 conclaves
        </p>
        <h1 className="hero__title" data-words data-now>
          Every table. Every round. <em>Every referral.</em>
        </h1>
        <p className="hero__lede" data-rise data-now>{app.lede}</p>
        <div data-rise data-now><Stores /></div>
      </div>

      <div className="table" aria-hidden="true">
        <div className="table__ring" />
        <Phone shot="round" className="table__phone" eager />
        {seats.map((s, i) => (
          <Seat key={s.name} s={s} angle={ANGLES[i]} speaking={i === speaker} order={i + 1} />
        ))}
      </div>

      <ul className="facts" data-stagger>
        {facts.map((f) => (
          <li key={f.label}><strong>{f.value}</strong>{f.label}</li>
        ))}
      </ul>
    </section>
  )
}
