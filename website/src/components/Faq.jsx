import { Plus } from 'lucide-react'
import { app, faq } from '../content.js'
import { asset } from '../lib/asset.js'

export default function Faq() {
  return (
    <section id="faq" className="qa">
      <header className="qa__head">
        <p className="eyebrow" data-reveal><i />Questions</p>
        <h2 className="h1" data-split>Good to <span className="grad">know.</span></h2>
        <p className="qa__lede" data-reveal>
          More answers on the <a href={`${asset('support/')}`}>support page</a>, or write to{' '}
          <a href={`mailto:${app.email}`}>{app.email}</a>.
        </p>
      </header>
      <div className="qa__list" data-reveal-group>
        {faq.map((f) => (
          <details key={f.q}>
            <summary>
              {f.q}
              <span className="qa__plus" aria-hidden="true"><Plus size={20} /></span>
            </summary>
            <p>{f.a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}
