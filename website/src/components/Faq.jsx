import { Plus } from 'lucide-react'
import { app, faq } from '../content.js'
import { asset } from '../lib/asset.js'

export default function Faq() {
  return (
    <section id="faq" className="qa">
      <header className="qa__head">
        <p className="kicker"><span className="kicker__dot" />Questions</p>
        <h2 className="h2" data-words>Good to <em>know.</em></h2>
        <p className="qa__lede" data-rise>
          More on the <a href={asset('support/')}>support page</a>, or write to <a href={`mailto:${app.email}`}>{app.email}</a>.
        </p>
      </header>
      <div className="qa__list" data-stagger>
        {faq.map((f) => (
          <details key={f.q}>
            <summary>
              {f.q}
              <span className="qa__plus" aria-hidden="true"><Plus size={18} /></span>
            </summary>
            <p>{f.a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}
