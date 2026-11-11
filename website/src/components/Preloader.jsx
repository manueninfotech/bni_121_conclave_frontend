import { useEffect, useRef, useState } from 'react'
import gsap from 'gsap'
import { prefersReducedMotion } from '../lib/smooth.js'
import { asset } from '../lib/asset.js'

/** A brief branded curtain; lifts on a short fixed timer and never blocks content. */
export default function Preloader() {
  const el = useRef(null)
  const [gone, setGone] = useState(() => prefersReducedMotion())

  useEffect(() => {
    if (gone) return
    const tl = gsap.timeline({ onComplete: () => setGone(true) })
    tl.from(el.current.querySelector('img'), { scale: 0.8, autoAlpha: 0, duration: 0.5, ease: 'back.out(1.6)' })
      .fromTo(el.current.querySelector('i'), { scaleX: 0 }, { scaleX: 1, duration: 0.6, ease: 'power2.inOut' }, 0.05)
      .to(el.current, { clipPath: 'inset(0 0 100% 0)', duration: 0.75, ease: 'expo.inOut' }, 0.75)
    return () => tl.kill()
  }, [gone])

  if (gone) return null
  return (
    <div ref={el} className="preloader" aria-hidden="true">
      <img src={asset('brand/mark-white.png')} alt="" width="104" height="104" />
      <i />
    </div>
  )
}
