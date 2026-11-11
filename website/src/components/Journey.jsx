import { useGSAP } from '@gsap/react'
import gsap from 'gsap'
import { useRef } from 'react'
import { journey } from '../content.js'
import Phone from './Phone.jsx'

// Wide screens scroll sideways through the day; narrow ones stack.
const WIDE = '(min-width: 1000px) and (min-height: 620px) and (prefers-reduced-motion: no-preference)'

export default function Journey() {
  const root = useRef(null)

  useGSAP(
    () => {
      const mm = gsap.matchMedia()
      mm.add(WIDE, () => {
        const track = root.current.querySelector('.journey__track')
        const distance = () => track.scrollWidth - window.innerWidth
        const tween = gsap.to(track, {
          x: () => -distance(),
          ease: 'none',
          scrollTrigger: {
            trigger: root.current,
            start: 'top top',
            end: () => `+=${distance()}`,
            pin: true,
            scrub: 0.6,
            invalidateOnRefresh: true,
          },
        })
        gsap.utils.toArray('.panel__phone', root.current).forEach((ph) => {
          gsap.fromTo(ph, { rotate: 8, y: 60 }, {
            rotate: -3, y: -20, ease: 'none',
            scrollTrigger: { trigger: ph, containerAnimation: tween, start: 'left right', end: 'right left', scrub: true },
          })
        })
      })
    },
    { scope: root },
  )

  return (
    <section id="journey" ref={root} className="journey">
      <div className="journey__track">
        <header className="journey__intro">
          <p className="kicker"><span className="kicker__dot" />The whole day</p>
          <h2 className="h2" data-words>From registration to <em>the last referral.</em></h2>
          <p className="journey__lede" data-rise>One app before, during and after the conclave. Scroll on.</p>
        </header>
        {journey.map((j, i) => (
          <article key={j.tag} className={`panel panel--${i + 1}`}>
            <div className="panel__copy">
              <p className="panel__tag"><span>{String(i + 1).padStart(2, '0')}</span>{j.tag}</p>
              <h3>{j.title}</h3>
              <p>{j.text}</p>
            </div>
            <div className="panel__art">
              <Phone shot={j.shot} alt={j.title} className="panel__phone" />
            </div>
          </article>
        ))}
      </div>
    </section>
  )
}
