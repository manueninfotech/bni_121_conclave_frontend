import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

export const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Wraps each word of `el` so it can blur in on its own. */
function words(el) {
  if (el.querySelector('.w')) return el.querySelectorAll('.w')
  const walk = (node) => {
    for (const child of [...node.childNodes]) {
      if (child.nodeType === 3) {
        const frag = document.createDocumentFragment()
        child.textContent.split(/(\s+)/).forEach((part) => {
          if (!part) return
          if (/^\s+$/.test(part)) frag.append(part)
          else {
            const s = document.createElement('span')
            s.className = 'w'
            s.textContent = part
            frag.append(s)
          }
        })
        child.replaceWith(frag)
      } else if (child.nodeType === 1) walk(child)
    }
  }
  walk(el)
  return el.querySelectorAll('.w')
}

/**
 * Page reveals, driven by data attributes:
 *   data-words   heading words blur and lift in, one after another
 *   data-rise    block lifts in
 *   data-stagger children lift in one after another
 */
export function initMotion(root) {
  document.documentElement.classList.remove('is-prep')
  if (reducedMotion()) return () => {}
  const ctx = gsap.context(() => {
    gsap.utils.toArray('[data-words]', root).forEach((el) => {
      const ws = words(el)
      gsap.from(ws, {
        yPercent: 40,
        autoAlpha: 0,
        filter: 'blur(10px)',
        duration: 0.9,
        stagger: 0.045,
        ease: 'power3.out',
        delay: el.hasAttribute('data-now') ? 0.15 : 0,
        scrollTrigger: el.hasAttribute('data-now') ? undefined : { trigger: el, start: 'top 86%', once: true },
      })
    })
    gsap.utils.toArray('[data-rise]', root).forEach((el) => {
      gsap.from(el, {
        y: 28,
        autoAlpha: 0,
        duration: 0.9,
        ease: 'power3.out',
        delay: el.hasAttribute('data-now') ? 0.5 : 0,
        scrollTrigger: el.hasAttribute('data-now') ? undefined : { trigger: el, start: 'top 90%', once: true },
      })
    })
    gsap.utils.toArray('[data-stagger]', root).forEach((el) => {
      gsap.from(el.children, {
        y: 32,
        autoAlpha: 0,
        duration: 0.8,
        stagger: 0.08,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 88%', once: true },
      })
    })
  }, root)
  // Pins are created by several components; measure everything in page order.
  ScrollTrigger.sort()
  ScrollTrigger.refresh()
  const onLoad = () => ScrollTrigger.refresh()
  window.addEventListener('load', onLoad)
  return () => {
    window.removeEventListener('load', onLoad)
    ctx.revert()
  }
}

export function scrollToId(id) {
  const el = id === 0 ? null : document.getElementById(id)
  const behavior = reducedMotion() ? 'auto' : 'smooth'
  if (!el) window.scrollTo({ top: 0, behavior })
  else window.scrollTo({ top: el.getBoundingClientRect().top + window.scrollY - 72, behavior })
}
