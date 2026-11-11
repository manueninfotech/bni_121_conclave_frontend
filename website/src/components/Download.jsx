import { asset } from '../lib/asset.js'
import Phone from './Phone.jsx'
import Stores from './Stores.jsx'

export default function Download() {
  return (
    <section id="download" className="cta">
      <div className="cta__card">
        <img className="cta__mark" src={asset('brand/mark-white.png')} alt="" aria-hidden="true" />
        <div className="cta__copy">
          <h2 className="h2 h2--light" data-words>Ready for your next conclave?</h2>
          <p data-rise>Download 1-2-1 Connect, set your Specific Ask, and make every table count.</p>
          <div data-rise><Stores light /></div>
        </div>
        <div className="cta__art">
          <Phone shot="people" alt="People you met, ready to save" className="cta__phone" />
        </div>
      </div>
    </section>
  )
}
