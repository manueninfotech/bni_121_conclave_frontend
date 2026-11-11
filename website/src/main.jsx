import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/plus-jakarta-sans'
import './styles.css'
import App from './App.jsx'

// Revealed headings stay hidden until their words are wrapped (see lib/motion.js).
document.documentElement.classList.add('is-prep')

const el = document.getElementById('root')
createRoot(el).render(
  <StrictMode>
    <App page={el.dataset.page || 'home'} />
  </StrictMode>,
)
