import { useEffect, useRef } from 'react'
import { startSmoothScroll } from './lib/smooth.js'
import { initPageMotion } from './lib/motion.js'
import Preloader from './components/Preloader.jsx'
import Nav from './components/Nav.jsx'
import Hero from './components/Hero.jsx'
import Band from './components/Band.jsx'
import Day from './components/Day.jsx'
import Features from './components/Features.jsx'
import Faq from './components/Faq.jsx'
import Download from './components/Download.jsx'
import Footer from './components/Footer.jsx'
import DocPage from './components/DocPage.jsx'

export default function App({ page }) {
  const root = useRef(null)
  const home = page === 'home'

  useEffect(() => {
    const stopScroll = startSmoothScroll()
    const stopMotion = initPageMotion(root.current)
    return () => {
      stopMotion()
      stopScroll()
    }
  }, [])

  return (
    <div ref={root}>
      <a className="skip" href="#main">Skip to content</a>
      {home && <Preloader />}
      <Nav home={home} />
      <main id="main">
        {home ? (
          <>
            <Hero />
            <Band />
            <Day />
            <Features />
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
