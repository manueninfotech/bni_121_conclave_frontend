import { app } from '../content.js'
import { asset } from '../lib/asset.js'

export default function Footer() {
  const base = import.meta.env.BASE_URL
  return (
    <footer className="footer">
      <div className="footer__top">
        <a className="footer__brand" href={base}>
          <img src={asset('brand/mark-white.png')} alt="" width="40" height="40" />
          {app.name}
        </a>
        <nav aria-label="Footer">
          <a href={`${base}support/`}>Support</a>
          <a href={`${base}privacy/`}>Privacy</a>
          <a href={`${base}terms/`}>Terms</a>
          <a href={`mailto:${app.email}`}>{app.email}</a>
        </nav>
        <a className="footer__by" href="/portfolio/">
          Built by <img src={asset('brand/manuen.png')} alt="Manuen Infotech" width="132" height="30" />
        </a>
      </div>
      <p className="footer__legal">&copy; 2026 Manuen Infotech. BNI and related marks belong to their respective owners.</p>
      <div className="footer__word" aria-hidden="true">1-2-1 Connect</div>
    </footer>
  )
}
