import { app } from '../content.js'
import { asset } from '../lib/asset.js'

export default function Footer() {
  const base = import.meta.env.BASE_URL
  return (
    <footer className="foot">
      <div className="foot__row">
        <a className="brand" href={base}>
          <img src={asset('brand/mark.png')} alt="" width="32" height="32" />
          <span>1-2-1 <b>Connect</b></span>
        </a>
        <nav aria-label="Footer">
          <a href={`${base}support/`}>Support</a>
          <a href={`${base}privacy/`}>Privacy</a>
          <a href={`${base}terms/`}>Terms</a>
          <a href={`mailto:${app.email}`}>{app.email}</a>
        </nav>
      </div>
      <div className="foot__row foot__row--small">
        <span>&copy; 2026 Manuen Infotech. BNI and related marks belong to their respective owners.</span>
        <a className="foot__by" href="/">
          A product of <img src={asset('brand/manuen.png')} alt="Manuen Infotech" width="110" height="25" />
        </a>
      </div>
    </footer>
  )
}
