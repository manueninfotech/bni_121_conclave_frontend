import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { Menu, X } from 'lucide-react'
import { app, navLinks } from '../content.js'
import { pauseScroll, prefersReducedMotion, resumeScroll, scrollToTarget } from '../lib/smooth.js'
import { asset } from '../lib/asset.js'

const home = () => import.meta.env.BASE_URL

export default function Nav({ home: onHome }) {
  const [active, setActive] = useState(-1)
  const [open, setOpen] = useState(false)
  const links = useRef([])
  const [pill, setPill] = useState({ left: 0, width: 0, on: false })
  const sheet = useRef(null)
  const toggle = useRef(null)
  const everOpened = useRef(false)

  // On the home page the highlight follows the section in view.
  useEffect(() => {
    if (!onHome) return
    const triggers = navLinks.map((l, i) =>
      ScrollTrigger.create({
        trigger: `#${l.id}`,
        start: 'top 50%',
        end: 'bottom 50%',
        onToggle: (self) => {
          if (self.isActive) setActive(i)
          else setActive((cur) => (cur === i ? -1 : cur))
        },
      }),
    )
    return () => triggers.forEach((t) => t.kill())
  }, [onHome])

  useLayoutEffect(() => {
    const el = links.current[active]
    setPill((p) => (el ? { left: el.offsetLeft, width: el.offsetWidth, on: true } : { ...p, on: false }))
  }, [active])

  useEffect(() => {
    if (!open && !everOpened.current) return
    everOpened.current = true
    const el = sheet.current
    const instant = prefersReducedMotion()
    gsap.killTweensOf(el)
    if (open) {
      pauseScroll()
      gsap.set(el, { visibility: 'visible' })
      gsap.fromTo(el, { clipPath: 'circle(0% at 100% 0%)' }, { clipPath: 'circle(150% at 100% 0%)', duration: instant ? 0 : 0.8, ease: 'power3.inOut' })
      el.querySelector('a')?.focus({ preventScroll: true })
    } else {
      resumeScroll()
      gsap.to(el, {
        clipPath: 'circle(0% at 100% 0%)',
        duration: instant ? 0 : 0.55,
        ease: 'power3.inOut',
        onComplete: () => gsap.set(el, { visibility: 'hidden' }),
      })
      toggle.current?.focus({ preventScroll: true })
    }
  }, [open])

  useEffect(() => {
    if (!open) return
    const onKey = (e) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  // In-page links scroll smoothly on the home page; elsewhere they navigate.
  const go = (e, id) => {
    if (!onHome) return
    e.preventDefault()
    const wasOpen = open
    setOpen(false)
    setTimeout(() => scrollToTarget(id), wasOpen && !prefersReducedMotion() ? 350 : 0)
  }
  const href = (id) => (onHome ? `#${id}` : `${home()}#${id}`)

  return (
    <>
      <header className="nav">
        <a className="nav__logo" href={onHome ? '#top' : home()} onClick={(e) => go(e, 0)} aria-label={`${app.name} home`}>
          <img src={asset('brand/mark.png')} alt="" width="34" height="34" />
          <span>{app.name}</span>
        </a>
        <nav className="nav__links" aria-label="Sections">
          <span
            className="nav__pill"
            style={{ transform: `translateX(${pill.left}px)`, width: pill.width, opacity: pill.on ? 1 : 0 }}
            aria-hidden="true"
          />
          {navLinks.map((l, i) => (
            <a
              key={l.id}
              ref={(n) => (links.current[i] = n)}
              href={href(l.id)}
              className={i === active ? 'is-active' : ''}
              onClick={(e) => go(e, l.id)}
            >
              {l.label}
            </a>
          ))}
          <a href={`${home()}support/`} className="nav__plain">Support</a>
        </nav>
        <a className="nav__cta" href={href('download')} onClick={(e) => go(e, 'download')}>Get the app</a>
        <button
          ref={toggle}
          className="nav__toggle"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-controls="mobile-menu"
          aria-label={open ? 'Close menu' : 'Open menu'}
        >
          {open ? <X size={22} /> : <Menu size={22} />}
        </button>
      </header>

      <nav id="mobile-menu" ref={sheet} className="sheet" aria-label="Menu" inert={!open}>
        {navLinks.map((l) => (
          <a key={l.id} href={href(l.id)} onClick={(e) => go(e, l.id)}>{l.label}</a>
        ))}
        <a href={`${home()}support/`}>Support</a>
        <a href={href('download')} onClick={(e) => go(e, 'download')}>Get the app</a>
        <div className="sheet__foot">
          <a href={`mailto:${app.email}`}>{app.email}</a>
        </div>
      </nav>
    </>
  )
}
