// The bank's journal (/blog). Posts are plain data: the page (Blog.tsx) lays them out like an EPRIS Daily article.
export type Block =
  | { p: string }
  | { h2: string }
  | { quote: string; by?: string }
  | { code: string }
  | { ul: string[] }
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
  dek: 'About 170 endpoints, one payment path with eleven checkpoints, a fraud engine of 28 rules and a session layer that assumes everything on the wire is hostile. The engineering behind TaxTech, from the first transfer to the last audit line.',
  date: '2026-11-13',
  section: 'Engineering',
  tags: ['TaxTech', 'Architecture', 'Payments', 'Security', 'Fraud detection', 'Idempotency', 'WebAuthn', 'Ledger'],
  cover: B + 'cover-art.webp',
  thumb: B + 'cover-square.webp',
  coverCap: 'TaxTech Bank: the first screen, with Leonardo’s Vitruvian Man, the drawing of proportion, behind the name',
  body: [
    { p: 'I started working on the bank in March. The part people notice is the face of it, and I will get to the face at the end. This article is about everything under it: what a request goes through before a single unit of TAX moves, what the server refuses to believe, and why a bank with a toy currency still needs the same discipline as a bank with a licence.' },
    { p: 'TaxTech is a laboratory bank. Its token, TAX, is not money, and no real card or account exists. That changes what is at stake, and it changes nothing about how the system has to behave. A transfer endpoint that can double-charge, a session that can be replayed or a ledger that does not add up is a bug whether the unit is euro or a game token, and the only way to find those bugs is to build the system as if it mattered.' },

    { h2: 'The shape of the API' },
    { p: 'The server exposes about 170 endpoints, grouped into fifteen route modules: accounts, cards, transfers, deposits, credits, foreign-exchange wallets, documents, a point-of-sale terminal, a hosted checkout for merchants, a marketplace, a city simulation and an admin area. Every module follows the same three layers. A route does only transport: it authenticates, validates, limits, and turns exceptions into one error format. A service owns the rules. A repository owns the SQL. Twenty service modules sit in the middle, and a route is never allowed to touch the database directly.' },
    { p: 'The number of endpoints is not the hard part. The hard part is that they are not independent. A card top-up, a transfer to a card number, a transfer between accounts, a point-of-sale sale, a QR payment in the city simulation and a hosted-checkout payment are six different doors into the same room, and all of them have to end in the same place: one atomic movement of balance, two ledger entries, one chain link, one audit line. If each door implemented that itself there would be six slightly different banks. So there is exactly one room.' },
    { code: 'route      auth · CSRF · rate limit · validation · idempotency key\nservice    rules, limits, 3-D Secure, fraud decision\ncore       PaymentCore.transfer(): the only code that moves money\nrepository SQL, parameterised, one place per table' },

    { h2: 'One payment, eleven checkpoints' },
    { p: 'Everything that moves money ends up in a single method, and a payment is a state machine rather than a function call. An order is created as pending, becomes processing when the funds are about to move, and ends as completed, failed or blocked. Nothing is ever deleted or edited backwards; a mistake is a new order that reverses the old one.' },
    { code: 'pending ──► processing ──► completed\n   │                  └────► failed\n   └──────────────────────────► blocked   (fraud: no balance was touched)' },
    { p: 'Between the request arriving and the money moving there are eleven checkpoints, in this order, and the order matters because the cheap ones run first.' },
    { ul: [
      'Transport and headers: a body size limit, an origin allowlist, a request identifier that follows the call through the logs.',
      'Authentication: a bearer token, or an HttpOnly cookie for browsers.',
      'CSRF: for cookie sessions, a double-submit token compared in constant time.',
      'Rate limit: a per-user bucket for money endpoints, a per-address one for anonymous calls.',
      'Validation: types, lengths and a ceiling on the amount before any business code sees the body.',
      'Idempotency: the request is fingerprinted and the key is reserved atomically.',
      'Ownership: the account and the card belong to the caller, and a budget limit that is crossed raises a notification.',
      '3-D Secure: above a threshold the payment needs a one-time challenge first.',
      'Fraud assessment: 28 rules score the transfer before any balance changes.',
      'Atomic movement: the debit, the credit and the balance check in one transaction.',
      'Afterwards: double-entry lines, a hash-chain link, a notification and an audit record.',
    ] },
    { p: 'The order of the first six is a security decision as much as a performance one. An unauthenticated caller must cost the server almost nothing, so the headers, the size limit and the token lookup come before any parsing of the payload. A malformed amount should be rejected before it is ever used as a key for anything.' },

    { h2: 'Idempotency: the same request, once' },
    { p: 'Mobile networks lose responses. A user taps Pay, the request reaches the server, the answer is dropped, the app retries, and an honest retry becomes a second charge. The defence is an Idempotency-Key header on every endpoint that moves money. The server takes the request body, serialises it as canonical JSON with sorted keys and no whitespace, and hashes it with SHA-256. That hash and the key are reserved with a single insert that does nothing on conflict, so when two identical requests arrive in the same millisecond exactly one of them wins the insert.' },
    { p: 'The reservation has four outcomes. A new key proceeds. A key still being processed is told that the first request is in progress. A key that has completed returns the stored response verbatim, with no second charge. And the same key with a different body is a conflict, because that is not a retry, it is either a bug or an attack, and it must never be answered with the result of a different payment.' },
    { code: 'new          → execute, then store the response\nprocessing   → the first request is still running\nreplay       → return the stored response, charge nothing\nconflict     → same key, different body: refused' },

    { h2: 'The atomic part' },
    { p: 'The most important line in the system is a condition inside an UPDATE. The usual way to write a transfer is to read the balance, check it in code, and write it back. Under concurrency that is a race: two requests read 100, both decide that 80 is affordable, and the account ends at minus 60. The check has to live in the same statement as the write.' },
    { code: 'UPDATE accounts\n   SET balance = balance - :amount\n WHERE id = :from AND balance >= :amount;\n-- zero rows updated = insufficient funds, nothing happened' },
    { p: 'If that statement touches no row, the payment fails and nothing else runs. The credit to the other side is in the same transaction, so there is no moment where money has left one account and not arrived at the other. The double-entry lines and the hash-chain link are written after the transaction commits, deliberately: a failure in bookkeeping must not undo a payment that already happened, and an end-of-day reconciliation catches any entry that went missing.' },

    { h2: 'A fraud engine with 28 rules' },
    { p: 'Before the balance moves, the transfer is scored. The engine has 28 rules in three layers, ordered by cost. Five rules in the first layer need only the arguments of the transfer itself: the amount, whether it is suspiciously round, a description that looks like a script. Twelve rules in the second layer read the sender’s history: velocity, a sudden jump from the usual size, a night-time transfer from someone who never pays at night, an account that was dormant and woke up. Eleven in the third look at the pair of sender and recipient and at the graph around them: a recipient that collects from many strangers and passes it on, a transfer split into pieces just under a limit, a counterparty that makes up most of the sender’s spending.' },
    { p: 'Each rule returns a belief between zero and one rather than a verdict, and the beliefs are combined as independent evidence with Noisy-OR, so that many weak signals add up without ever overflowing past certainty.' },
    { code: 'score = 1 − ∏ (1 − pᵢ)\n\n0–25 low · 26–50 medium · 51–75 high · 76+ critical' },
    { p: 'The cheap rules run first and the engine stops as soon as the result is critical, so an obvious attack never pays for the expensive graph queries. A critical score sets the order to blocked, writes a risk event and a notification, and returns before any balance is read for writing. The decision is stored with the rules that fired, so a verdict can always be explained afterwards, and so I can tune a rule that is too eager.' },

    { h2: 'Sessions that assume theft' },
    { p: 'A session token is 32 random bytes from the operating system’s generator, encoded as 43 URL-safe characters. The server keeps sessions in a table with an expiry, a device description and the time of last use, and it shows the list to the user, who can revoke any of them or all but the current one. The list never contains tokens: the current session is identified by a SHA-256 fingerprint, so a screenshot of the screen cannot leak a credential.' },
    { p: 'Sessions are sliding: when fewer than seven days are left, the server extends the expiry and says so in a response header. The token itself is not rotated, and that is deliberate. Rotating it on every renewal makes parallel requests from one client invalidate each other, which turns a security feature into random sign-outs. An active user is never logged out, and a token that stops being used ages out on its own.' },
    { p: 'Browsers get a different transport from the apps. A browser session is an HttpOnly cookie with the __Host- prefix, which means it is Secure, bound to the exact host and cannot be set by a sibling subdomain. JavaScript cannot read it, so a script injected into the page cannot steal it. The price of cookies is CSRF, so every state-changing request must also carry a second token, set as a readable cookie and echoed in a header, and the two are compared with a constant-time function. Apps use the bearer header and are not exposed to CSRF at all.' },

    { h2: 'Passwords, codes and passkeys' },
    { p: 'Passwords are hashed with bcrypt at cost 12, which is about a quarter of a second on a modern CPU, a price an attacker pays for every guess and a user pays once per sign-in. A password change asks for the old password first, and an account that signs in with Apple has no password to reset at all.' },
    { p: 'Reset codes are never stored. What is stored is a SHA-256 of the reset identifier and the code together, so a leaked table cannot be replayed. The code is compared in constant time, it expires, asking for a new one retires the old one, and after five wrong attempts it is burned, so a six-digit code cannot be brute-forced inside its lifetime.' },
    { p: 'The strongest sign-in is no password at all. Passkeys use WebAuthn: the device holds a private key that never leaves it, and the server holds only a public key. User verification is required, which means a Face ID or Touch ID check on every sign-in, not just possession of the device. The challenge is single-use and is removed from the session the moment it is read. The server checks the relying-party identifier and the origin, so a phishing page on another domain gets a signature that is worthless. And it stores a signature counter, so a cloned authenticator that goes backwards is detectable.' },

    { h2: 'Rate limits that know who is asking' },
    { p: 'A rate limit is only as good as its key. Sign-in is limited on the pair of address and identity, which stops a targeted guess against one account from one address, and the address part alone stops a spray of many accounts from one address. Registration is limited by address. Money endpoints are limited per signed-in user, not per address, so that one customer cannot be locked out by another behind the same office network, and one account cannot flood the payment path.' },
    { p: 'The address itself needs care. Behind a reverse proxy the first entry of the forwarded-for header is whatever the client chose to send, and trusting it lets an attacker rotate a fake address on every request and walk around any limit. The server reads the address the proxy itself observed, and there is a test that spoofs the header and asserts that it makes no difference. The application is meant to be the second line of defence behind the proxy, not the only one.' },

    { h2: 'Headers, input and the unknown' },
    { p: 'Every response carries the same set of headers: content sniffing off, no framing at all, a referrer policy that never leaks paths across origins, a year of HSTS, a content security policy that forbids objects and base-tag tricks, and a permissions policy that switches off the camera, microphone, location, payment API, USB, serial and Bluetooth for the API origin. Cross-origin access is an explicit allowlist. A path that does not exist answers 404, not 405, so the shape of the API cannot be mapped by trying methods.' },
    { p: 'Input is bounded before it is interpreted. Text fields have a hard length limit, amounts have a ceiling that protects against overflow and arithmetic surprises, bodies have a size limit, and identifiers in a path are typed by the router before a handler runs. Queries are parameterised, and user input is never spliced into SQL text. Every request gets an identifier, taken from the caller if it sent one or generated if it did not, and the identifier travels with the response and into the logs, so that an incident can be reconstructed from one string.' },

    { h2: 'A point-of-sale terminal is a small bank' },
    { p: 'If one endpoint shows how much complexity hides behind a button, it is the card terminal. A sale is one call. But the life of a card payment is not a sale. A hold reserves funds for a pre-authorisation. A capture settles it, and the amount may exceed the hold by a tip of up to twenty percent. A void releases a hold that was never captured. A refund may be partial, in which case the merchant keeps the fee, and a full refund waives it. A dispute credits the customer provisionally the moment it is raised, asks the merchant to respond, and resolves one way or the other.' },
    { p: 'Each of those transitions has rules about what it may follow, who may call it and how much money it may touch, and the rules interact. A dispute can only be contested with evidence that fits the reason, and a contest wins only when the reason is not-recognised and the payment went through 3-D Secure, because that is where the liability shifts from the merchant to the issuer. A payment above the threshold cannot complete without a challenge: a six-digit one-time code that lives for 180 seconds and then yields a session token valid for 300 seconds, which the payment spends exactly once. Settlement of the merchant’s takings is scheduled for the next day. All of it is nine endpoints, and every one of them has to agree with the others about what a payment is allowed to become.' },
    { img: B + 'paid.webp', cap: 'The receipt of a completed payment carries a TT-XXXX-XXXX-XXXX code and a QR code that the public verification page checks against the ledger', wide: true },

    { h2: 'Proof you can hold in your hand' },
    { p: 'Every number that the bank prints can be checked. Each transaction of an account gets a hash that includes the hash of the one before it, so changing a row anywhere in the history breaks every later link, and the verification of the chain finds it. A double-entry ledger records every transfer as a debit and a credit, and an end-of-day reconciliation proves that the two columns are equal and hunts for entries that belong to no order.' },
    { p: 'Receipts and statements are signed in a way that anyone can check and nobody can forge. The code on a receipt is twelve base32 characters from an HMAC-SHA256 over the kind of document, its reference and its owner, using a key that exists only on the server. The public page that verifies a code shows masked details and nothing that identifies a person, and it checks the code against the ledger rather than against its own memory.' },
    { img: B + 'line-t.webp', cap: 'The landing explains the nine mechanisms as stations of a metro line, in the order a payment meets them', wide: true },

    { h2: 'How I know it works' },
    { p: 'There are 226 automated tests, and the ones I trust most are the ones that attack. One registers a user and checks that the new account is never an administrator. One asserts that routes I removed from the API are really gone and that the public catalogue lists nothing else. One sends the same top-up twice with the same key and checks that the balance moved once, and then sends the same key with a different amount and expects a conflict. One turns on the rate limit and hammers sign-in. One spoofs the forwarded-for header. One reads the security headers off a response. The point of such tests is that a refactor cannot silently turn a protection off.' },
    { p: 'The weak points I know about, I keep on a list, and I would rather have the list than the illusion that it is empty. A system like this is never finished: it is only checked more often than it is changed.' },

    { h2: 'The face of it' },
    { p: 'None of this is visible, which is why the front of the bank has to say it. The first screen is Leonardo’s Vitruvian Man, the drawing of a body measured against a circle and a square, over the name TaxTech Bank. It is not decoration. The Italian Renaissance is where banking learned to count: the Medici kept the accounts of the Pope in Rome, and in 1494 a friar named Luca Pacioli printed the rules of double entry, the same rule that the ledger under this site still obeys. A bank is a system of measure, and the picture is a diagram of measure.' },
    { p: 'The card is black with a guilloche rosette, the engraving pattern of banknotes, drawn by a formula on every render: twenty-two curves, each a circle whose radius is modulated by two cosines. Six faces of Rome stand in a cover flow beside it. The rest of the page is a night map of Rome on which a payment travels, a metro line that explains the nine mechanisms above, and Roma Live, a city of 18 659 buildings that pays in real time.' },
    { img: B + 'city.webp', cap: 'Roma Live: thousands of places paying through the point-of-sale pipeline, with a verdict on every payment', wide: true },
    { p: 'Eight months after the first line of server code, the bank has an API I can reason about, a payment path that cannot double-charge, a ledger that adds up, and a front page I would trust. The rules that survived every rebuild are the same ones on both sides of the screen: one place where money moves, every claim provable, and no input believed before it is checked.' },
  ],
}];

export const postBySlug = (slug: string) => POSTS.find(p => p.slug === slug);
