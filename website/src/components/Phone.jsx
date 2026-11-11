import { asset } from '../lib/asset.js'

/** An iPhone-style frame around one of the app's real screens. */
export default function Phone({ shot, alt = '', className = '', eager = false }) {
  return (
    <div className={`phone ${className}`}>
      <img src={asset(`shots/${shot}.webp`)} alt={alt} width="860" height="1869" loading={eager ? 'eager' : 'lazy'} />
    </div>
  )
}
