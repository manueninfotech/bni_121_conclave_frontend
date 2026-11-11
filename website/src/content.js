// All copy and links for the site. Components only render what is here.

export const app = {
  name: '1-2-1 Connect',
  lede: 'Your conclave, run from your phone: where to sit, who is speaking, when to pass business, and everyone you met, saved when the day is done.',
  appStore: 'https://apps.apple.com/in/app/bni-1-2-1-conclave/id6809010007',
  playStore: 'https://play.google.com/store/apps/details?id=com.manuen.conclave_1_2_1',
  email: 'connect@manuen.com',
}

export const navLinks = [
  { id: 'round', label: 'A round' },
  { id: 'journey', label: 'The day' },
  { id: 'features', label: 'Features' },
  { id: 'faq', label: 'FAQ' },
]

// The table in the hero: six seats around the phone. Fictional people.
export const seats = [
  { initial: 'P', name: 'Priya', trade: 'Chartered Accountant' },
  { initial: 'K', name: 'Kiran', trade: 'Real Estate' },
  { initial: 'L', name: 'Lakshmi', trade: 'Catering' },
  { initial: 'R', name: 'Rahul', trade: 'Insurance' },
  { initial: 'S', name: 'Sneha', trade: 'Digital Marketing' },
  { initial: 'A', name: 'Arjun', trade: 'Architecture' },
]

export const facts = [
  { value: '60s', label: 'bio for each person' },
  { value: '30s', label: 'referral slot each' },
  { value: '3-8', label: 'people a table, kept even' },
  { value: 'Offline', label: 'at the venue, synced later' },
]

// One round of six people: six 60s bios, then six 30s referrals (9 minutes).
export const round = {
  people: ['Priya', 'Kiran', 'Lakshmi', 'Rahul', 'Sneha', 'Arjun'],
  bio: 60,
  referral: 30,
  phases: [
    {
      key: 'bio',
      title: 'Bios, one at a time',
      text: 'Everyone gets sixty seconds. The card shows who is speaking, their business and their ask, with a timer every phone at the table shares.',
      shot: 'round',
    },
    {
      key: 'referral',
      title: 'The referral slot opens',
      text: 'Thirty seconds each to pass business. The "Give a referral" button appears only now, so the room stays on the person speaking.',
      shot: 'referral',
    },
    {
      key: 'move',
      title: 'Time to move',
      text: 'When the round ends, the app tells you your next table and who you will meet there. No lists, no shouting across the hall.',
      shot: 'home',
    },
  ],
}

export const journey = [
  {
    tag: 'Before',
    title: 'Find your conclave. Take your seat.',
    text: 'Browse by region and date, register in seconds, and add your Specific Ask so every table knows what you are looking for.',
    shot: 'conclaves',
  },
  {
    tag: 'On the day',
    title: 'Check in with a scan.',
    text: 'Your table captain scans your QR code each round, or you tap "I’m here". It all works without signal.',
    shot: 'card',
  },
  {
    tag: 'After',
    title: 'See what you built.',
    text: 'Every round you attended, the referrals you gave and received, and everyone you sat with, ready to save to your contacts.',
    shot: 'summary',
  },
]

export const features = [
  { icon: 'scale', title: 'Balanced tables', text: 'Three to eight a table, sizes within one of each other, and never two people from the same category.' },
  { icon: 'wifi-off', title: 'Works without signal', text: 'Attendance and referrals are kept on your phone and sync when you reconnect.' },
  { icon: 'scan', title: 'Captains and walk-ins', text: 'Captains scan members in, stand-ins can step up, and late arrivals join from the next round.' },
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
