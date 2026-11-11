import Phone from './Phone.jsx'
import Stores from './Stores.jsx'

export default function Download() {
  return (
    <section id="download" className="download">
      <div className="download__rays" aria-hidden="true" />
      <div className="download__lead">
        <h2 className="download__title" data-split>Ready for your next conclave?</h2>
        <p data-reveal>Download 1-2-1 Connect, set your Specific Ask, and make every table count.</p>
        <div data-reveal><Stores /></div>
      </div>
      <div className="download__art" data-reveal>
        <Phone shot="card" alt="Your 1-2-1 Connect card" className="download__phone" />
      </div>
    </section>
  )
}
