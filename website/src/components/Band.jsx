import { band } from '../content.js'
import { asset } from '../lib/asset.js'

function Row({ hidden }) {
  return (
    <ul aria-hidden={hidden || undefined}>
      {band.map((t) => (
        <li key={t}>
          {t}
          <img src={asset('brand/mark.png')} alt="" width="30" height="30" />
        </li>
      ))}
    </ul>
  )
}

export default function Band() {
  return (
    <div className="band" aria-hidden="true">
      <div className="band__track">
        <Row />
        <Row hidden />
      </div>
    </div>
  )
}
