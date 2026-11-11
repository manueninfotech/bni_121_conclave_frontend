import { useRef, useState } from 'react'
import { useGSAP } from '@gsap/react'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { round } from '../content.js'
import { reducedMotion } from '../lib/motion.js'
import Phone from './Phone.jsx'

// One round of six: six bios, six referrals, then a minute to move (600s).
const MOVE = 60
const segments = [
  ...round.people.map((p, i) => ({ kind: 'bio', who: p, start: i * round.bio, len: round.bio })),
  ...round.people.map((p, i) => ({ kind: 'referral', who: p, start: round.people.length * round.bio + i * round.referral, len: round.referral })),
]
const TALK = segments.at(-1).start + segments.at(-1).len
const TOTAL = TALK + MOVE
segments.push({ kind: 'move', who: null, start: TALK, len: MOVE })

const C = 200
const R = 168
const polar = (sec, r = R) => {
  const a = (sec / TOTAL) * Math.PI * 2 - Math.PI / 2
  return [C + Math.cos(a) * r, C + Math.sin(a) * r]
}
const arc = (from, to, r = R) => {
  const [x1, y1] = polar(from, r)
  const [x2, y2] = polar(to, r)
  const large = (to - from) / TOTAL > 0.5 ? 1 : 0
  return `M ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2}`
}
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`

export default function RoundClock() {
  const root = useRef(null)
  const [p, setP] = useState(0.06)

  // Created in page order (before the journey's pin) so later sections measure past it.
  useGSAP(() => {
    if (reducedMotion()) return
    ScrollTrigger.create({
      trigger: root.current,
      start: 'top top',
      end: '+=260%',
      pin: '.clock__stage',
      scrub: true,
      refreshPriority: 1,
      onUpdate: (self) => setP(Math.min(0.999, Math.max(0.002, self.progress))),
    })
  }, { scope: root })

  const sec = p * TOTAL
  const seg = segments.find((s) => sec >= s.start && sec < s.start + s.len) ?? segments[0]
  const phase = round.phases.findIndex((ph) => ph.key === seg.kind)
  const left = seg.start + seg.len - sec
  const [nx, ny] = polar(sec, R)

  return (
    <section id="round" ref={root} className="clock">
      <div className="clock__stage">
        <header className="clock__head">
          <p className="kicker kicker--light"><span className="kicker__dot" />One round, start to finish</p>
          <h2 className="h2 h2--light" data-words>Ten minutes. Six people. <em>Nobody talks over anyone.</em></h2>
        </header>

        <div className="clock__body">
          <div className="dial">
            <svg viewBox="0 0 400 400" role="img" aria-label={`Round clock at ${mmss(sec)}: ${round.phases[phase].title}`}>
              <circle className="dial__track" cx={C} cy={C} r={R} />
              {segments.map((s) => (
                <path
                  key={`${s.kind}-${s.start}`}
                  className={`dial__seg dial__seg--${s.kind} ${sec >= s.start ? 'is-done' : ''}`}
                  d={arc(s.start + 1.2, s.start + s.len - 1.2)}
                />
              ))}
              <path className="dial__progress" d={arc(0.01, Math.max(0.02, sec))} />
              <circle className="dial__knob" cx={nx} cy={ny} r="11" />
            </svg>
            <div className="dial__face">
              <span className={`dial__tag dial__tag--${seg.kind}`}>
                {seg.kind === 'bio' ? 'Bio' : seg.kind === 'referral' ? 'Referral slot' : 'Move'}
              </span>
              <strong className="dial__who">{seg.who ?? 'Next table'}</strong>
              <span className="dial__time">{mmss(left)}</span>
              <small>{mmss(sec)} of {mmss(TOTAL)}</small>
            </div>
          </div>

          <div className="clock__side">
            <div className="clock__phone">
              {round.phases.map((ph, i) => (
                <Phone key={ph.key} shot={ph.shot} alt={ph.title} className={i === phase ? 'is-on' : ''} />
              ))}
            </div>
            <ol className="phases">
              {round.phases.map((ph, i) => (
                <li key={ph.key} className={i === phase ? 'is-on' : i < phase ? 'is-past' : ''}>
                  <span className="phases__no">{i + 1}</span>
                  <div>
                    <h3>{ph.title}</h3>
                    <p>{ph.text}</p>
                  </div>
                </li>
              ))}
            </ol>
          </div>
        </div>
      </div>
    </section>
  )
}
