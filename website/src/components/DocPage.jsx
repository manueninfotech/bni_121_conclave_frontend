import privacy from '../content/privacy.html?raw'
import terms from '../content/terms.html?raw'
import support from '../content/support.html?raw'

const pages = { privacy, terms, support }
const labels = [['support', 'Support'], ['privacy', 'Privacy'], ['terms', 'Terms']]

// Each page file starts with a comment block of "key: value" lines.
function parse(src) {
  const m = src.match(/^<!--([\s\S]*?)-->/)
  const meta = {}
  for (const line of (m ? m[1] : '').split('\n')) {
    const i = line.indexOf(':')
    if (i > 0) meta[line.slice(0, i).trim()] = line.slice(i + 1).trim()
  }
  return { meta, body: src.replace(/^<!--[\s\S]*?-->\s*/, '') }
}

export default function DocPage({ page }) {
  const { meta, body } = parse(pages[page] ?? pages.support)
  const base = import.meta.env.BASE_URL
  const title = page === 'support' ? 'How can we help?' : meta.title
  return (
    <>
      <section className="doc-hero">
        <div className="aurora aurora--soft" aria-hidden="true"><i /><i /><i /></div>
        <div className="doc-hero__inner">
          <p className="eyebrow eyebrow--light" data-reveal><i />1-2-1 Connect</p>
          <h1 className="h1" data-split>{title}</h1>
          <p className="doc-hero__sub" data-reveal>
            {meta.updated ? `Last updated ${meta.updated}` : 'Answers to common questions, and how to reach us.'}
          </p>
          <nav className="doc-tabs" aria-label="Pages" data-reveal>
            {labels.map(([id, label]) => (
              <a key={id} href={`${base}${id}/`} aria-current={id === page ? 'page' : undefined}>{label}</a>
            ))}
          </nav>
        </div>
      </section>
      <section className="doc-body">
        <article className={`doc ${page === 'support' ? 'doc--support' : ''}`} data-reveal dangerouslySetInnerHTML={{ __html: body }} />
      </section>
    </>
  )
}
