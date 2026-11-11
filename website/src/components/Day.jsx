import { useGSAP } from '@gsap/react'
import gsap from 'gsap'
import { Check } from 'lucide-react'
import { useRef } from 'react'
import { scenes } from '../content.js'
import { scrollToTarget } from '../lib/smooth.js'
import Phone from './Phone.jsx'

// Side-by-side scene effects run only where scenes are sticky (see styles.css).
const WIDE =
  '(min-width: 1101px) and (min-height: 600px) and (prefers-reduced-motion: no-preference), ' +
  '(min-width: 961px) and (min-height: 600px) and (orientation: landscape) and (prefers-reduced-motion: no-preference)'

function Scene({ s, no, flip }) {
  return (
    <article id={`scene-${s.id}`} className={`scene ${flip ? 'is-flip' : ''}`} style={{ '--c1': s.bg[0], '--c2': s.bg[1], '--accent': s.accent }}>
      <div className="scene__inner">
        <span className="scene__ghost" aria-hidden="true">{no}</span>
        <div className="scene__copy">
          <p className="scene__step"><span>{no}</span>{s.step}</p>
          <h3 className="scene__title">{s.title}</h3>
          <p className="scene__text">{s.text}</p>
          <ul className="scene__points">
            {s.points.map((p) => (
              <li key={p}><Check size={16} aria-hidden="true" />{p}</li>
            ))}
          </ul>
        </div>
        <div className="scene__art">
          <Phone shot={s.shot} alt={s.title} className="scene__phone" />
        </div>
      </div>
    </article>
  )
}

export default function Day() {
  const root = useRef(null)

  useGSAP(
    () => {
      const mm = gsap.matchMedia()
      mm.add(WIDE, () => {
        const list = gsap.utils.toArray('.scene', root.current)
        list.forEach((c, i) => {
          gsap.fromTo(
            c.querySelector('.scene__phone'),
            { rotateX: 24, rotateZ: i % 2 ? -4 : 4, scale: 0.84, y: 90 },
            { rotateX: 0, rotateZ: 0, scale: 1, y: 0, ease: 'none', scrollTrigger: { trigger: c, start: 'top 85%', end: 'top 10%', scrub: true } },
          )
          gsap.from(c.querySelectorAll('.scene__copy > *'), {
            y: 40,
            autoAlpha: 0,
            stagger: 0.08,
            ease: 'power3.out',
            scrollTrigger: { trigger: c, start: 'top 60%', end: 'top 15%', scrub: 0.6 },
          })
          // As the next scene slides over, this one settles back.
          const next = list[i + 1]
          if (next) {
            gsap.to(c.querySelector('.scene__inner'), {
              scale: 0.93,
              autoAlpha: 0.35,
              ease: 'none',
              scrollTrigger: { trigger: next, start: 'top bottom', end: 'top top', scrub: true },
            })
          }
        })
      })
    },
    { scope: root },
  )

  return (
    <section id="day" ref={root} className="day">
      <header className="day__intro">
        <p className="eyebrow" data-reveal><i />The day, round by round</p>
        <h2 className="h1" data-split>
          One app from registration to <span className="grad">the last referral.</span>
        </h2>
        <p className="day__lede" data-reveal>
          One-to-one networking works when everyone knows where to be and what to do. The app makes sure they do.
        </p>
        <ol className="day__jump" data-reveal-group>
          {scenes.map((s, i) => (
            <li key={s.id}>
              <button onClick={() => scrollToTarget(`scene-${s.id}`)}>
                <strong>{String(i + 1).padStart(2, '0')}</strong>
                {s.step}
              </button>
            </li>
          ))}
        </ol>
      </header>
      <div className="scenes">
        {scenes.map((s, i) => (
          <Scene key={s.id} s={s} no={String(i + 1).padStart(2, '0')} flip={i % 2 === 1} />
        ))}
      </div>
    </section>
  )
}
