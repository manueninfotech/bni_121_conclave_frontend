import { useEffect, useRef } from 'react'
import { initMotion } from './lib/motion.js'
import Nav from './components/Nav.jsx'
import Hero from './components/Hero.jsx'
import RoundClock from './components/RoundClock.jsx'
import Journey from './components/Journey.jsx'
import Deck from './components/Deck.jsx'
import Faq from './components/Faq.jsx'
import Download from './components/Download.jsx'
import Footer from './components/Footer.jsx'
import DocPage from './components/DocPage.jsx'

export default function App({ page }) {
  const root = useRef(null)
  const home = page === 'home'

  useEffect(() => initMotion(root.current), [])

  return (
    <div ref={root}>
      <a className="skip" href="#main">Skip to content</a>
      <Nav home={home} />
      <main id="main">
        {home ? (
          <>
            <Hero />
            <RoundClock />
            <Journey />
            <Deck />
            <Faq />
            <Download />
          </>
        ) : (
          <DocPage page={page} />
        )}
      </main>
      <Footer />
    </div>
  )
}
