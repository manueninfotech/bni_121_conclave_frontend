// All copy and links for the site. Components only render what is here.

export const app = {
  name: '1-2-1 Connect',
  lede: 'Your conclave, run from your phone: where to sit, who is speaking, when to pass business, and everyone you met, saved when the day is done.',
  appStore: 'https://apps.apple.com/app/id6809010007',
  playStore: 'https://play.google.com/store/apps/details?id=com.manuen.conclave_1_2_1',
  email: 'connect@manuen.com',
}

export const navLinks = [
  { id: 'day', label: 'The day' },
  { id: 'features', label: 'Features' },
  { id: 'faq', label: 'FAQ' },
]

// The hero strip. Facts about how a round runs, not usage claims.
export const stats = [
  { value: 60, suffix: 's', label: 'Bio for each person' },
  { value: 30, suffix: 's', label: 'Referral slot each' },
  { value: 8, prefix: '3-', label: 'People per table, kept even' },
  { value: 1, label: 'Tap to pass a referral' },
]

export const band = ['Live round timer', 'One-tap referrals', 'QR attendance', 'Works offline', 'Balanced tables', 'Conclave summary', 'Save every contact']

// The day, as full-screen scenes. Colours are flat and full-strength.
export const scenes = [
  {
    id: 'register',
    step: 'Before',
    title: 'Find your conclave. Take your seat.',
    text: 'Browse upcoming conclaves by region and date, register in seconds, and add your Specific Ask so every table knows what you are looking for.',
    points: ['Register and pay in the app', 'Your business category keeps competitors apart', 'Add the day to your calendar'],
    shot: 'conclaves',
    bg: ['#b00e29', '#d8061b'],
    accent: '#ffd36b',
  },
  {
    id: 'round',
    step: 'Every round',
    title: 'Know who is speaking, every second.',
    text: 'Your table, the people at it and the speaking order, with a live timer every phone at the table shares, even with no signal.',
    points: ['Read each person’s ask before they speak', 'The deck follows the speaker on its own', 'When the round ends, the app tells you where to go'],
    shot: 'round',
    bg: ['#5c0716', '#7a0a1e'],
    accent: '#ff8f9c',
  },
  {
    id: 'refer',
    step: 'Referral slot',
    title: 'Pass business in one tap.',
    text: 'When the referral slot opens, give a referral to anyone at your table and add a note so the lead is clear.',
    points: ['Opens only in the referral slot, so the room stays focused', 'Track every referral you give and receive', 'Record closed business when a lead pays off'],
    shot: 'referral',
    bg: ['#1f1a1c', '#2e2427'],
    accent: '#ff5a6e',
  },
  {
    id: 'after',
    step: 'After',
    title: 'See what you built.',
    text: 'Your summary shows every round you attended, the referrals you gave and received, and everyone you sat with.',
    points: ['Save the people you met to your contacts', 'Share your own card with a QR code', 'Everything syncs once you are back online'],
    shot: 'summary',
    bg: ['#d8061b', '#e8344a'],
    accent: '#fff3c4',
  },
]

export const features = [
  { icon: 'wifi-off', title: 'Works without signal', text: 'Attendance and referrals are kept on your phone at the venue and sync when you reconnect.' },
  { icon: 'scale', title: 'Balanced tables', text: 'Tables stay between three and eight people, sizes never differ by more than one, and no two people share a category.' },
  { icon: 'scan', title: 'Captains and walk-ins', text: 'Table captains scan members in, stand-ins can step up, and late arrivals join from the next round.' },
  { icon: 'shield', title: 'Private by default', text: 'Other members never see your phone number or email in the directory.' },
  { icon: 'bell', title: 'Timely alerts', text: 'Know when a round starts, when to move, and when a referral comes your way.' },
  { icon: 'coffee', title: '1-2-1 meetings', text: 'Request a one-to-one with any member and keep every meeting in one place.' },
]

export const faq = [
  { q: 'Who is 1-2-1 Connect for?', a: 'Members and guests attending BNI 1-2-1 conclaves. Organisers run the event; the app guides everyone through it.' },
  { q: 'Is it free?', a: 'The app is free. Some conclaves charge a registration fee for the event itself, shown before you pay.' },
  { q: 'Does it work without internet?', a: 'Yes. The round timer, attendance and referrals work offline at the venue and sync when you are back online.' },
  { q: 'Can I cancel a registration?', a: 'Not in the app. The schedule seats and pairs you with other members, so contact the organiser if you cannot attend.' },
  { q: 'How do I delete my account?', a: 'In the app, go to Profile, then Delete account. It removes your account and everything linked to it.' },
]
