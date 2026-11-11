import { siApple, siGoogleplay } from 'simple-icons'
import { app } from '../content.js'

function Logo({ path }) {
  return (
    <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor" aria-hidden="true">
      <path d={path} />
    </svg>
  )
}

/** App Store and Google Play buttons. `light` for use on red. */
export default function Stores({ light = false }) {
  return (
    <div className={`stores ${light ? 'stores--light' : ''}`}>
      <a className="store" href={app.appStore} target="_blank" rel="noreferrer">
        <Logo path={siApple.path} />
        <span><small>Download on the</small>App Store</span>
      </a>
      <a className="store" href={app.playStore} target="_blank" rel="noreferrer">
        <Logo path={siGoogleplay.path} />
        <span><small>Get it on</small>Google Play</span>
      </a>
    </div>
  )
}
