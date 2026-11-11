import { useGSAP } from '@gsap/react'
import gsap from 'gsap'
import { useEffect, useRef } from 'react'
import { Handshake, MapPin } from 'lucide-react'
import { app, stats } from '../content.js'
import { prefersReducedMotion } from '../lib/smooth.js'
import Phone from './Phone.jsx'
import Stores from './Stores.jsx'

export default function Hero() {
  const root = useRef(null)

  useGSAP(
    () => {
      if (prefersReducedMotion()) return
      gsap.from('[data-hero-in]', { y: 26, autoAlpha: 0, duration: 1, stagger: 0.09, delay: 1.5, ease: 'power3.out' })
      gsap.from('.hero__phone', { y: 140, autoAlpha: 0, rotate: 0, duration: 1.4, stagger: 0.16, delay: 1.2, ease: 'expo.out' })
      gsap.from('.chip', { scale: 0.6, autoAlpha: 0, duration: 0.9, stagger: 0.12, delay: 1.9, ease: 'back.out(1.7)' })
      gsap.to('.hero__copy', {
        yPercent: -10,
        autoAlpha: 0.2,
        ease: 'none',
        scrollTrigger: { trigger: root.current, start: 'top top', end: 'bottom 30%', scrub: true },
      })
      gsap.to('.hero__stage', {
        yPercent: 8,
        ease: 'none',
        scrollTrigger: { trigger: root.current, start: 'top top', end: 'bottom top', scrub: true },
      })
    },
    { scope: root },
  )

  // Phones and chips drift against the pointer for depth.
  useEffect(() => {
    if (prefersReducedMotion() || !window.matchMedia('(pointer: fine)').matches) return
    const items = gsap.utils.toArray('[data-depth]', root.current).map((el) => ({
      d: Number(el.dataset.depth),
      x: gsap.quickTo(el, 'x', { duration: 1.1, ease: 'power3' }),
      y: gsap.quickTo(el, 'y', { duration: 1.1, ease: 'power3' }),
    }))
    const onMove = (e) => {
      const nx = e.clientX / window.innerWidth - 0.5
      const ny = e.clientY / window.innerHeight - 0.5
      items.forEach((c) => {
        c.x(nx * c.d)
        c.y(ny * c.d)
      })
    }
    window.addEventListener('pointermove', onMove, { passive: true })
    return () => window.removeEventListener('pointermove', onMove)
  }, [])

  return (
    <section id="top" ref={root} className="hero">
      <div className="aurora" aria-hidden="true"><i /><i /><i /></div>
      <div className="hero__grid" aria-hidden="true" />

      <div className="hero__stage" aria-hidden="true">
        <div className="hero__glow" />
        <div data-depth="-30" className="hero__slot hero__slot--back">
          <Phone shot="home" className="hero__phone" eager />
        </div>
        <div data-depth="-55" className="hero__slot hero__slot--front">
          <Phone shot="round" className="hero__phone" eager />
        </div>
        <div data-depth="-90" className="chip chip--speak">
          <span className="chip__dot" />
          <span><strong>Priya is speaking</strong><small>00:25 left in her bio</small></span>
        </div>
        <div data-depth="-75" className="chip chip--ref">
          <span className="chip__ico"><Handshake size={18} /></span>
          <span><strong>Referral passed</strong><small>To Kiran, KK Realty</small></span>
        </div>
        <div data-depth="-110" className="chip chip--table">
          <span className="chip__ico chip__ico--light"><MapPin size={18} /></span>
          <span><strong>Next: Table 7</strong><small>Round 4 of 6</small></span>
        </div>
      </div>

      <div className="hero__copy">
        <p className="eyebrow" data-hero-in><i />For BNI 1-2-1 conclaves</p>
        <h1 className="hero__title" data-split data-split-hero>
          Every table. Every round. <span className="grad">Every referral.</span>
        </h1>
        <p className="hero__lede" data-hero-in>{app.lede}</p>
        <div className="hero__cta" data-hero-in>
          <Stores light />
        </div>
      </div>

      <dl className="hero__stats" data-hero-in>
        {stats.map((s) => (
          <div key={s.label}>
            <dd>
              {s.prefix}
              <span data-count={s.value} data-count-hero>{s.value}</span>
              {s.suffix}
            </dd>
            <dt>{s.label}</dt>
          </div>
        ))}
      </dl>
    </section>
  )
}
