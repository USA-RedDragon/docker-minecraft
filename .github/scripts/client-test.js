const { spawn } = require('node:child_process')
const minecraftData = require('minecraft-data')
const { ping } = require('minecraft-protocol')
const mineflayer = require('mineflayer')

const [container, host] = process.argv.slice(2)
const port = 25565
const kickReason = 'Server is restarting'
const countdown = ['1 minute', '45 seconds', '30 seconds', '15 seconds', '10 seconds', '5 seconds', '4 seconds', '3 seconds', '2 seconds', '1 second']
  .map((time) => `Server restart in ${time}...`)

const started = Date.now()
const events = []
const log = (name, type, detail = '') => {
  events.push({ name, type, detail, at: Date.now() })
  console.log(`${((Date.now() - started) / 1000).toFixed(1).padStart(6)}s ${name} ${type} ${detail}`)
}
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function clientVersion () {
  const { version } = await ping({ host, port })
  const candidates = minecraftData.postNettyVersionsByProtocolVersion.pc[version.protocol] || []
  return candidates.map((v) => v.minecraftVersion).find((v) => minecraftData.supportedVersions.pc.includes(v))
}

function join (name, version) {
  return new Promise((resolve, reject) => {
    const bot = mineflayer.createBot({ host, port, username: name, version, auth: 'offline' })
    const timer = setTimeout(() => reject(new Error(`${name} did not log in within 60s`)), 60000)
    bot.once('login', () => {
      clearTimeout(timer)
      log(name, 'logged in')
      resolve(bot)
    })
    bot.once('spawn', () => log(name, 'spawned'))
    bot.on('messagestr', (message) => log(name, 'chat', message))
    bot.on('kicked', (reason) => log(name, 'kicked', typeof reason === 'string' ? reason : JSON.stringify(reason)))
    bot.on('error', (error) => log(name, 'error', error.message))
  })
}

function runPreStop () {
  return new Promise((resolve) => {
    const child = spawn('docker', ['exec', container, '/pre-stop'])
    let output = ''
    child.stdout.on('data', (data) => { output += data })
    child.stderr.on('data', (data) => { output += data })
    child.on('close', (code) => resolve({ code, output }))
  })
}

async function main () {
  const version = await clientVersion()
  if (!version) {
    console.log(`::warning::client test skipped: mineflayer does not support the protocol of ${container}`)
    process.exit(2)
  }
  console.log(`client version ${version}`)

  await join('StayingBot', version)
  const preStop = runPreStop()
  await sleep(10000)
  await join('LateBot', version)
  const { code, output } = await preStop
  console.log(`pre-stop exited ${code}: ${output.trim()}`)
  await sleep(2000)

  const failures = []
  const of = (name, type) => events.filter((e) => e.name === name && e.type === type)
  const kickedWith = (name) => of(name, 'kicked').find((e) => e.detail.includes(kickReason))

  if (code !== 0 || !output.includes('Saved the game')) failures.push('pre-stop did not exit 0 after saving the game')

  const announcements = of('StayingBot', 'chat').map((e) => e.detail).filter((m) => m.startsWith('Server restart in'))
  if (JSON.stringify(announcements) !== JSON.stringify(countdown)) {
    failures.push(`StayingBot saw announcements ${JSON.stringify(announcements)}, expected ${JSON.stringify(countdown)}`)
  }
  if (!kickedWith('StayingBot')) failures.push(`StayingBot was not kicked with "${kickReason}"`)

  const lateLogin = of('LateBot', 'logged in')[0]
  const lateKick = kickedWith('LateBot')
  if (!lateKick) failures.push(`LateBot was not kicked with "${kickReason}"`)
  else if (lateKick.at - lateLogin.at > 5000) failures.push(`LateBot was kicked ${lateKick.at - lateLogin.at}ms after joining, expected under 5000ms`)

  for (const failure of failures) console.log(`::error::${failure}`)
  process.exit(failures.length ? 1 : 0)
}

main().catch((error) => {
  console.log(`::error::${error.message}`)
  process.exit(1)
})
