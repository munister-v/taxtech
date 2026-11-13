// The bank's journal (/blog). Posts are plain data: the page (Blog.tsx) lays them out like an EPRIS Daily article.
export type Block =
  | { p: string }
  | { h2: string }
  | { quote: string; by?: string }
  | { code: string }
  | { img: string; cap: string; wide?: boolean; ratio?: string }
  | { phones: { img: string; cap: string }[]; cap: string };

export type Post = {
  slug: string;
  title: string;
  dek: string;
  date: string;        // ISO day
  section: string;
  tags: string[];
  cover: string;
  thumb?: string;
  coverCap: string;
  body: Block[];
};

const B = '/blog/how-i-built-my-bank/';

export const POSTS: Post[] = [{
  slug: 'how-i-built-my-own-bank',
  title: 'How I Built My Own Bank',
  dek: 'Work on the bank began in March. This is the visual story of TaxTech: a black card with a guilloche rosette, six faces of Rome, a metro line under the hood, a city that pays in real time and a first screen that went through nine versions before it found Leonardo.',
  date: '2026-11-13',
  section: 'Design',
  tags: ['TaxTech', 'Card design', 'Guilloche', 'Rome', 'three.js', 'iOS', 'Landing page'],
  cover: B + 'cover-art.webp',
  thumb: B + 'cover-square.webp',
  coverCap: 'Pay like Rome.: Leonardo’s Vitruvian Man drawn in warm light over the night map of Rome',
  body: [
    { p: 'I started working on the bank in March, long before it had a face. First came the server and the rules: a router that decides which requests may stay on the phone, accounts, transfers, a ledger. The face came later, and it came fast. In the last days of October the repository filled up with the things this story is about: a card, a web cabinet, a shop, a landing page that I have rebuilt more times than I want to count, and a name, TaxTech, with a token called TAX.' },
    { p: 'This is not a story about the ledger, the fraud engine or the hash chain, although all of them are real and all of them run on the server. It is a story about how the bank looks. A bank is mostly a feeling of trust, and on a screen trust is made of type, colour, weight and motion. I spent more hours on that than on anything else, and almost every decision got reversed at least once.' },

    { h2: 'Black, and one yellow' },
    { p: 'The first visual pass was a typical neobank: a living aurora behind the balance, gradient cards, a ring chart of categories, a chat bubble. It looked like every fintech template on Dribbble, and I deleted it the same afternoon. The second pass was the opposite: flat black and white, no gradients, square corners, small caps for labels. It was honest but cold, so the third pass brought back rounded corners and the system font, and kept exactly one colour, a signal yellow, #ffd400.' },
    { p: 'The rule that survived every later redesign came from that day: yellow is for money and for the one action that matters. The balance is yellow. The main button is yellow. Rows in the activity list are not, icons are not, category chips are not. When I broke the rule, the screen immediately started to look cheap, so I wrote it into a commit message to remind myself: "yellow only on the balance". Later the app moved to gold, and the landing kept the yellow for its buttons, but the principle of one accent did not change.' },

    { h2: 'The card is the brand' },
    { p: 'A bank card is the only physical thing a bank gives you, and even a virtual one carries that memory. So the card got more attention than any screen. It went through a builder with ten colours, materials and emblems, a holographic sheen that follows the tilt of the phone, a flip to a back side with the CVV, seven Roman designs drawn by hand in SVG, and then those designs replaced by photographs. What stayed at the centre is the default face: black, with a gold guilloche rosette.' },
    { p: 'Guilloche is the engraving pattern on banknotes and old share certificates: dozens of fine curves that interlock and are almost impossible to copy by hand. I did not want a texture file, I wanted the real thing, drawn by maths every time the card renders. Each curve is a circle whose radius is modulated by two cosines, and twenty-two of them are laid around the centre with a phase shift.' },
    { code: 'r(t) = R · (1 − d − s + d·cos(7t + φ) + s·cos(14t − φ))\n\nφ = 2πk / 22,   k = 0 … 21\nd = 0.22,  s = 0.07,  R = 46' },
    { p: 'Seven lobes give the rosette its flower; the second harmonic at fourteen bends every petal into a small wave, and that is what makes it read as engraving rather than a logo. The same function, with ten curves and six lobes, draws the medallions that hold the icons on quick actions in the app, so the card and the buttons belong to one family. The stroke is a thin gold at low opacity, so under the light sheen the rosette appears and disappears as the card moves.' },
    { img: B + 'card-guilloche.webp', cap: 'The default face: black, gold guilloche rosette, chip, contactless mark, VIRTUAL in place of a network logo', wide: true },
    { p: 'The rest of the face is quiet on purpose. The TaxTech mark top left, a chip drawn in CSS gradients, the contactless waves, four groups of digits with only the last four visible, the holder name in spaced capitals and the word VIRTUAL where Visa or Mastercard would be. Every number starts with 0000, so no card can ever be mistaken for a real one. Earlier versions had the balance, the card type and a label on the face; I removed all of it. A card that explains itself looks like a mock-up.' },

    { h2: 'Six faces of Rome' },
    { p: 'The bank has a city, and the city is Rome. The first Roman cards were vector drawings: the Pantheon portico, an aqueduct at sunset, the three tiers of the Colosseum, an aureus coin, the SPQR eagle, stone and marble textures with gold foil. They were charming and they were clip art. The next day I replaced them with photographs from Wikimedia Commons: the Colosseum by day and by night, the Pantheon, the Temple of Saturn in the Forum, the Aqua Claudia, Carrara marble. Each photograph keeps its author and licence in the design picker.' },
    { img: B + 'card-colosseum.webp', cap: 'Six faces of Rome on the landing: a 3D cover flow you can drag, with glare that follows the active card. Colosseum by night: John Samuel, CC BY-SA 4.0', wide: true },
    { p: 'A photograph on a card is harder than it seems. The type has to sit on whatever the photo does, so every face gets the same dark gradient from the left edge and the same inner glow along the top, and the mark and digits are white with a soft shadow. The photos are cropped so that the architecture runs behind the chip, never behind the digits. On the landing the six faces stand in a cover flow: the active card faces you, the others turn away in perspective, and a glare band slides across whichever one you drag.' },
    { img: B + 'card-pantheon.webp', cap: 'Pantheon: Nhartmannphotos, CC BY-SA 4.0. Forum (Temple of Saturn): Nicholas Hartmann. Aqua Claudia: Mario2912. Marble: Solarence. All CC BY-SA 4.0', wide: true },

    { h2: 'Why Rome, and which Rome' },
    { p: 'Rome came from the shop. The bank pays at Saint Agnes, a fashion storefront that prices everything in TAX, and the shop already lived in an Italian mood. But there are two Romes you can put on a screen. One is antiquity: a serif in the style of inscriptions, a meander border, laurel wreaths, Roman numerals, Latin mottos. I tried it for a full day, on the landing and in the app, and it turned the bank into a museum shop. The other Rome is the city now: evening light on stone, a scooter, an espresso at a counter, a payment at a till. That is the Rome that stayed.' },
    { p: 'For a while the app wore it as a modern Italian minimalism: tabs named Studio, Piazza, Registro, Carte and Fisco, thin lines, plenty of air and one Italian sentence on the sign-in screen. The tabs have English names again, the sentence stayed.' },
    { quote: 'Fidati, ma verifica.', by: 'The sign-in headline of the TaxTech app. Trust, but verify.' },

    { h2: 'One evening, told by the scroll' },
    { p: 'The landing has to sell a feeling of paying in Rome without a single word of explanation. The answer was a scene where the scroll runs a clock. The first two screens sit on one night map of Rome, real streets from OpenStreetMap painted on a canvas in dark blue with thin gold lines. As you scroll, the clock moves from 18:30 to 23:55, a payment travels along the streets, and the city names the place: the Roman Forum, aperitivo, 850 TAX; the Pantheon, dinner, 3 200 TAX; the Trevi Fountain, gelato, 180 TAX.' },
    { img: B + 'evening.webp', cap: 'One evening in Rome: the scroll moves the clock, the map moves to the next place and an iOS-style notification shows the debit and the balance', wide: true },
    { p: 'The clock is set in a very thin weight at a very large size, so that it reads as light rather than type. Each payment arrives as a notification drawn exactly like the one iOS shows, with the TaxTech mark in a yellow tile, the merchant, the amount and the remaining balance. It took several passes to remove everything decorative from this scene: a card that hovered over the map, stop indicators, a progress hairline, hero buttons. What remains is a clock, a place and a payment.' },

    { h2: 'Tap. Paid.' },
    { p: 'The next scene is the oldest gesture in card payments. A photograph of a hand holding a card over a terminal, graded down to the night palette of the map so the transition does not jump. The camera pushes in, NFC waves ring out from the card, the word Tap. appears; then a flash, and Paid. in yellow, with a tick in a circle, the notification and a paper receipt that slides in at an angle.' },
    { img: B + 'tap.webp', cap: 'Tap.: the camera pushes in on the terminal. Photo: SumUp on Unsplash', wide: true },
    { img: B + 'paid.webp', cap: 'Paid.: the receipt carries a TT-XXXX-XXXX-XXXX code and a QR that the public check page verifies against the ledger', wide: true },
    { p: 'The receipt is my favourite small object on the site. It has the mark, a monospaced merchant line, the amount in a heavier weight, a perforated edge, a green PAID stamp turned a few degrees and a verification code. The code is not decoration: twelve base32 characters of an HMAC over the receipt, and the same code opens a public page that checks it. That page is drawn like a banknote, with a guilloche medallion, a wave ribbon, leader dots and microprint, because a document that proves something should look like one.' },

    { h2: 'Under the hood is a metro line' },
    { p: 'Every bank landing has a grid of feature tiles with icons. Mine had one too, and nobody would ever read it. The mechanisms are worth reading, though: passkeys, 3-D Secure, idempotency keys, a fuzzy fraud engine, authorization holds, atomic transfers, double-entry, a hash chain, verifiable receipts. So they became stations on a metro line across Rome, in the order a payment meets them.' },
    { p: 'The first version was a train dot running along a line on the map. The second was a station platform in CSS. The third, which is on the site now, is a full 3D station built in three.js and loaded only when you get close: a graphite train with a gold line and lit windows brakes into the depth, plug doors, an LED board, a mirror floor, light strips on a vaulted ceiling, a headlight beam and hanging station signs. The station names follow the map; the title above it is Line T.' },
    { img: B + 'line-t.webp', cap: 'Line T.: a three.js station with a graphite train, gold livery and hanging signs that follow the map', wide: true },
    { p: 'Beneath the station, each mechanism has a tile with a tiny looping scene in pure CSS: an OTP that fills digit by digit and a timer that runs out, a coin sent twice and charged once, three fraud checks with the third one failing, a hash chain where each block carries the previous hash, a QR with a scan line. Every number in the tiles is taken from the server code: an OTP lives 180 seconds, a 3-D Secure token 300, there are 28 fraud rules combined by Noisy-OR.' },

    { h2: 'The app on a light stage' },
    { p: 'For a long time the landing showed phone mock-ups drawn in HTML. They were close, but a visitor can always tell. Now the landing has one light section in the middle of all that night, with an iPhone frame built in CSS, titanium edge and all, and real screens of the app inside it. Three pills switch between them: Account, Cards, QR.' },
    { img: B + 'app.webp', cap: 'All in the app: a CSS iPhone on a light stage, real screens from the iOS app, Account, Cards and QR', wide: true },
    { p: 'The screens are taken in the iOS Simulator from a debug build pointed at a local server, with a demo customer, Giulia, and the status bar fixed at 9:41 like in Apple keynotes. The home screen in the app went through its own journey: a crimson and gold aurora, a glass strip of actions, gold medallions, a balance in a monospaced face. The card on the home screen uses the same guilloche as the landing, so the brand does not change when you cross from the site into the app.' },
    { phones: [
      { img: '/landing/app-s-home.webp', cap: 'Home' },
      { img: '/landing/app-s-card-designs.webp', cap: 'Card designs' },
      { img: '/landing/app-s-qr-paid.webp', cap: 'QR paid' },
    ], cap: 'Three screens from the iOS app, Tax Tech: Digital Finance Lab' },

    { h2: 'A city that pays' },
    { p: 'The biggest visual piece is not on the landing at all. Roma Live, at /roma, is the centre of Rome in 3D: 18 659 buildings and 7 384 places from OpenStreetMap, from Testaccio to Villa Borghese, lit by how much money passes through them today. A café that sells a lot glows orange, a quiet street stays grey. The server runs the city around the clock on Rome time, with markets in the mornings, the Angelus on Sunday, the papal audience on Wednesday, nights in Trastevere and San Lorenzo, and the real weather of Rome.' },
    { img: '/landing/roma-live.webp', cap: 'Roma Live at night: every building is a place, its colour is its turnover today', wide: true },
    { p: 'Visually the hard part was restraint. The first version flickered with every payment; the calmer one keeps the light changes slow, softens the map at its edge so the city dissolves instead of ending, and lets the camera drift. On the landing the live scene used to freeze the scroll for a few seconds while the city loaded, so the section now shows a still frame of it and only the numbers are live: turnover, payments, places and the clock in Rome.' },
    { img: B + 'city.webp', cap: 'Rome, live.: on the landing the city is a still frame, the turnover and the payment count update every 15 seconds', wide: true },

    { h2: 'Rome by QR code' },
    { p: 'The last section before the shop is a real invoice. A place in Rome, a price, a QR code and a five-minute timer. Scan it with the phone camera and the TaxTech app opens the payment; pay it, and the payment flies onto the map of Rome next to it. The design is plain on purpose: a dark map on the left, a white QR on a dark card on the right, the amount in TAX with the currency in small yellow capitals.' },
    { img: B + 'qr.webp', cap: 'Rome by QR code: a live invoice for a real place, paid from a phone and shown on the map', wide: true },

    { h2: 'The heroes I threw away' },
    { p: 'The first screen of the landing is where I lost the most time. In order, it was: a centred headline with a tilted card in the style of Apple Card; a research platform with heat maps; a travertine page with a brick-red accent and a Roman arch; a page in the Saint Agnes language with square buttons; a cinematic Colosseum with arches that caught fire and sparks rising through them; a night map with a card hovering over its pin; a live pill with Rome\'s weather, a giant climbing turnover and real payments as notifications; a full-bleed photograph of the Colosseum; a ten-second night flight over Roma Live as a looping video.' },
    { p: 'Each of them taught me one thing. The live hero was overloaded: three moving things compete and none of them wins. The Colosseum photograph was beautiful and boring, because every Rome page has one. The video was clumsy: a loop always shows its seam. Then came a hero of chrome: the TaxTech mark extruded from the app\'s own SVG, a gold TAX coin, chrome spheres turning in a studio light. It was technically the best of them and the emptiest. It could have belonged to any company that owns a logo.' },
    { p: 'The hero that stayed has no logo and no objects at all. It is a drawing: Leonardo\'s Vitruvian Man, a man inside a circle and a square, the oldest picture of proportion in Europe. It fits a bank for a reason that is not decoration. The Italian Renaissance is where banking learned to count: the Medici kept the accounts of the Pope in Rome, and in 1494 a friar named Luca Pacioli printed the rules of double entry, the same rule that the ledger under this site still follows. A bank is a system of measure, and the picture is a diagram of measure.' },
    { p: 'The public-domain scan is turned into light: the paper is dropped out, the ink becomes warm gold on the dark, and the edges dissolve into the night map. It drifts a few pixels over forty seconds and lifts away with the headline when you scroll. On a phone the man stands above the headline, so the first thing you see is him and the second is the sentence.' },
    { img: B + 'hero.webp', cap: 'Pay like Rome.: the first screen today. Leonardo da Vinci, Vitruvian Man, c. 1490, Gallerie dell’Accademia, Venice. Public domain', wide: true },
    { p: 'A design that stutters is a bad design, however it looks in a still frame. The landing first weighed 1.1 MB before the first paint; now it is about 0.3 MB, because every photograph below the fold, the three.js station loads only when they are a screen or two away. The banking app is its own chunk and loads while the browser is idle. On a CPU slowed four times, the first render went from 3.0 seconds of main-thread work to 1.9. The card sheen moves by transform instead of repainting nine cards every frame, headline words no longer animate blur, and the rosette turns without a blur filter. Scripts and styles ship as brotli; the app chunk went from 421 KB to 82 KB on the wire.' },

    { p: 'Eight months after the first line of server code, the bank has a card I would like to hold, a city that pays while I sleep and a front page I no longer want to rebuild. That will not last. But the rules that survived every rebuild will: one accent, a card without explanations, real screens instead of mock-ups, Rome as it is now, and motion that never fights the scroll.' },
  ],
}];

export const postBySlug = (slug: string) => POSTS.find(p => p.slug === slug);
