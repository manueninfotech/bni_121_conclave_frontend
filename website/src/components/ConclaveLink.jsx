import { useEffect, useRef, useState } from 'react'
import { reducedMotion } from '../lib/motion.js'
import { startShards } from '../lib/shards.js'
import Stores from './Stores.jsx'

const API = 'https://conclave-backend.blackpond-26884e90.centralindia.azurecontainerapps.io/api'

/** The conclave id from /conclave/c/<id>. */
function linkId() {
  const parts = window.location.pathname.split('/').filter(Boolean)
  const i = parts.indexOf('c')
  return i >= 0 ? decodeURIComponent(parts[i + 1] || '') : ''
}

function when(c) {
  if (!c.startDate) return ''
  const fmt = (iso) =>
    new Date(iso).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' })
  const start = fmt(c.startDate)
  const end = c.endDate ? fmt(c.endDate) : ''
  const day = end && end !== start ? `${start} to ${end}` : start
  return c.startTime ? `${day}, ${c.startTime}` : day
}

const statusText = {
  completed: 'This conclave has ended.',
  cancelled: 'This conclave was cancelled.',
  running: 'This conclave is happening now.',
}

/**
 * Where a shared conclave link lands when the app is not installed (with the
 * app, the phone opens the conclave in the app instead). Shows the public
 * facts only, and how to get the app.
 */
export default function ConclaveLink() {
  const canvas = useRef(null)
  const [state, setState] = useState({ loading: true })
  useEffect(() => startShards(canvas.current, { count: 80, still: reducedMotion() }), [])
  useEffect(() => {
    const id = linkId()
    if (!id) return setState({ missing: true })
    fetch(`${API}/public/conclaves/${encodeURIComponent(id)}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((c) => {
        document.title = `${c.name} | 1-2-1 Connect`
        setState({ c })
      })
      .catch(() => setState({ missing: true }))
  }, [])

  const { c } = state
  return (
    <>
      <section className="doc-hero">
        <canvas ref={canvas} className="doc-hero__shards" aria-hidden="true" />
        <div className="doc-hero__inner">
          <p className="kicker" data-rise data-now><span className="kicker__dot" />BNI 1-2-1 conclave</p>
          <h1 className="h1" data-now>
            {c ? c.name : state.missing ? 'This link has expired' : 'Loading the conclave'}
          </h1>
          {c && (
            <p className="doc-hero__sub" data-rise data-now>
              {[when(c), c.venue || c.region].filter(Boolean).join(' · ')}
            </p>
          )}
        </div>
      </section>
      <section className="doc-body">
        <article className="doc" data-rise data-now>
          {c && statusText[c.status] && <p><strong>{statusText[c.status]}</strong></p>}
          <p>
            {state.missing
              ? 'We could not find this conclave. Ask the person who shared it for a new link, or browse conclaves in the app.'
              : 'Get 1-2-1 Connect, then open this link again on your phone. It takes you straight to the conclave, where you can see the details and register.'}
          </p>
          <Stores />
        </article>
      </section>
    </>
  )
}
