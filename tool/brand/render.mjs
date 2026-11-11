// Rasterises SVG files to transparent PNGs with Chrome (exact SVG rendering).
// node tool/brand/render.mjs <out.png> <width> <svg file> [background]
import puppeteer from 'puppeteer-core'
import { readFileSync } from 'node:fs'
const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8')) // [{svg, out, width, bg}]
const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true })
const p = await b.newPage()
for (const j of jobs) {
  const svg = readFileSync(j.svg, 'utf8')
  const m = svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/)
  const w = j.width, h = Math.round((w * Number(m[2])) / Number(m[1]))
  await p.setViewport({ width: w, height: h, deviceScaleFactor: 1 })
  await p.setContent(`<html><body style="margin:0;background:${j.bg || 'transparent'}">${svg.replace('<svg ', `<svg style="display:block;width:${w}px;height:${h}px" `)}</body></html>`)
  await p.screenshot({ path: j.out, omitBackground: !j.bg, clip: { x: 0, y: 0, width: w, height: h } })
}
await b.close()
