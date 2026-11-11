import { useEffect, useState } from 'react'
import { Menu, X } from 'lucide-react'
import { app, navLinks } from '../content.js'
import { scrollToId } from '../lib/motion.js'
import { asset } from '../lib/asset.js'

/** A plain top bar: brand left, links right, a hairline once you scroll. */
export default function Nav({ home }) {
  const [scrolled, setScrolled] = useState(false)
  const [open, setOpen] = useState(false)
  const base = import.meta.env.BASE_URL

  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 8)
    on()
    window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])

  useEffect(() => {
    document.documentElement.classList.toggle('menu-open', open)
    if (!open) return
    const onKey = (e) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  const go = (e, id) => {
    setOpen(false)
    if (!home) return
    e.preventDefault()
    scrollToId(id)
  }
  const href = (id) => (home ? `#${id}` : `${base}#${id}`)

  return (
    <header className={`top ${scrolled ? 'is-scrolled' : ''} ${open ? 'is-open' : ''}`}>
      <div className="top__bar">
        <a className="brand" href={home ? '#top' : base} onClick={(e) => go(e, 0)} aria-label={`${app.name} home`}>
          <img src={asset('brand/mark.png')} alt="" width="36" height="36" />
          <span>1-2-1 <b>Connect</b></span>
        </a>
        <nav className="top__links" aria-label="Sections">
          {navLinks.map((l) => (
            <a key={l.id} href={href(l.id)} onClick={(e) => go(e, l.id)}>{l.label}</a>
          ))}
          <a href={`${base}support/`}>Support</a>
        </nav>
        <a className="top__cta" href={href('download')} onClick={(e) => go(e, 'download')}>Get the app</a>
        <button className="top__toggle" onClick={() => setOpen((v) => !v)} aria-expanded={open} aria-controls="menu" aria-label={open ? 'Close menu' : 'Open menu'}>
          {open ? <X size={22} /> : <Menu size={22} />}
        </button>
      </div>
      <nav id="menu" className="drawer" aria-label="Menu" inert={!open}>
        {navLinks.map((l) => (
          <a key={l.id} href={href(l.id)} onClick={(e) => go(e, l.id)}>{l.label}</a>
        ))}
        <a href={`${base}support/`}>Support</a>
        <a className="drawer__cta" href={href('download')} onClick={(e) => go(e, 'download')}>Get the app</a>
      </nav>
    </header>
  )
}
