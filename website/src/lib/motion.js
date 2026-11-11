import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { SplitText } from 'gsap/SplitText'
import { prefersReducedMotion } from './smooth.js'

gsap.registerPlugin(ScrollTrigger, SplitText)

const fontsReady = () =>
  Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 2000))])

/**
 * Declarative page-wide reveals, driven by data attributes:
 *   data-split         heading lines rise out of a mask
 *   data-reveal        fade-up
 *   data-reveal-group  children fade up in a stagger
 *   data-count         number counts up to its rendered value
 */
export function initPageMotion(root) {
  let alive = true
  let ctx

  fontsReady().then(() => {
    if (!alive) return
    document.documentElement.classList.remove('is-splitting')
    if (prefersReducedMotion()) return

    ctx = gsap.context(() => {
      gsap.utils.toArray('[data-split]', root).forEach((el) => {
        const hero = el.hasAttribute('data-split-hero')
        SplitText.create(el, {
          type: 'lines',
          mask: 'lines',
          linesClass: 'line',
          autoSplit: true,
          onSplit: (self) =>
            gsap.from(self.lines, {
              yPercent: 112,
              duration: 1.15,
              stagger: 0.09,
              ease: 'expo.out',
              delay: hero ? 1.25 : 0,
              scrollTrigger: hero ? undefined : { trigger: el, start: 'top 88%', once: true },
            }),
        })
      })

      gsap.utils.toArray('[data-reveal]', root).forEach((el) => {
        gsap.from(el, {
          y: 36,
          autoAlpha: 0,
          duration: 1,
          ease: 'power3.out',
          scrollTrigger: { trigger: el, start: 'top 92%', once: true },
        })
      })

      gsap.utils.toArray('[data-reveal-group]', root).forEach((group) => {
        gsap.from(group.children, {
          y: 44,
          autoAlpha: 0,
          duration: 0.95,
          stagger: 0.07,
          ease: 'power3.out',
          scrollTrigger: { trigger: group, start: 'top 88%', once: true },
        })
      })

      gsap.utils.toArray('[data-count]', root).forEach((el) => {
        const state = { v: 0 }
        gsap.to(state, {
          v: Number(el.dataset.count),
          duration: 1.6,
          ease: 'power2.out',
          delay: el.hasAttribute('data-count-hero') ? 1.6 : 0,
          onUpdate: () => (el.textContent = Math.round(state.v)),
          scrollTrigger: el.hasAttribute('data-count-hero') ? undefined : { trigger: el, start: 'top 92%', once: true },
        })
      })

      ScrollTrigger.sort()
      ScrollTrigger.refresh()
    }, root)
  })

  // Late-loading images can change section heights; re-measure once settled.
  const onLoad = () => ScrollTrigger.refresh()
  window.addEventListener('load', onLoad)

  return () => {
    alive = false
    window.removeEventListener('load', onLoad)
    ctx?.revert()
  }
}
