import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/archivo/wdth.css'
import '@fontsource-variable/figtree'
import './styles.css'
import App from './App.jsx'

// Headings stay hidden only until they have been split into animated lines.
document.documentElement.classList.add('is-splitting')

const el = document.getElementById('root')
createRoot(el).render(
  <StrictMode>
    <App page={el.dataset.page || 'home'} />
  </StrictMode>,
)
