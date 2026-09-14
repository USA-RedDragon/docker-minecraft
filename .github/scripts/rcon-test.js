const net = require('node:net')

const [host, password, variant] = process.argv.slice(2)
const port = 25575
const prefix = variant === 'paper' ? 'minecraft:' : ''
const patched = variant === 'forge' || variant === 'neoforge'
const maxPacketSize = 4096
const markerDelay = 300
const replacement = Buffer.from([0xef, 0xbf, 0xbd])
const elements = 10
const element = 'é'.repeat(600)

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function open () {
  const socket = await new Promise((resolve, reject) => {
    const s = net.createConnection({ host, port }, () => resolve(s))
    s.once('error', reject)
  })
  let buffer = Buffer.alloc(0)
  const packets = []
  let wake = () => {}
  socket.on('data', (data) => {
    buffer = Buffer.concat([buffer, data])
    while (buffer.length >= 4 && buffer.length >= 4 + buffer.readInt32LE(0)) {
      const size = buffer.readInt32LE(0)
      packets.push({ size, id: buffer.readInt32LE(4), type: buffer.readInt32LE(8), body: buffer.subarray(12, 4 + size - 2) })
      buffer = buffer.subarray(4 + size)
    }
    wake()
  })

  const write = (id, type, body) => {
    const payload = Buffer.from(body, 'utf8')
    const packet = Buffer.alloc(14 + payload.length)
    packet.writeInt32LE(10 + payload.length, 0)
    packet.writeInt32LE(id, 4)
    packet.writeInt32LE(type, 8)
    payload.copy(packet, 12)
    socket.write(packet)
  }

  const next = async (timeout) => {
    const deadline = Date.now() + timeout
    while (packets.length === 0) {
      const left = deadline - Date.now()
      if (left <= 0) throw new Error(`no RCON packet within ${timeout}ms`)
      await new Promise((resolve) => {
        wake = resolve
        setTimeout(resolve, left)
      })
    }
    return packets.shift()
  }

  write(1, 3, password)
  for (;;) {
    const packet = await next(10000)
    if (packet.type === 2) {
      if (packet.id !== 1) throw new Error('RCON authentication failed')
      break
    }
  }

  let nextId = 10
  const run = async (command) => {
    if (Buffer.byteLength(command) > 1400) throw new Error(`command is too long for one RCON read: ${command.slice(0, 40)}`)
    const id = nextId
    nextId += 2
    write(id, 2, command)
    await sleep(markerDelay)
    write(id + 1, 2, '')
    const replies = []
    for (;;) {
      const packet = await next(10000)
      if (packet.id === id + 1) return replies
      if (packet.id === id) replies.push(packet)
    }
  }

  return { run, close: () => socket.destroy() }
}

async function main () {
  const rcon = await open()
  const failures = []

  const say = await rcon.run(`${prefix}say RCON empty reply check`)
  console.log(`empty output: ${say.length} reply packet(s)`)
  if (say.length === 0) failures.push('the server sent no reply packet for a command with empty output')

  await rcon.run(`${prefix}data modify storage rcontest:utf8 v set value [""]`)
  for (let i = 0; i < elements; i++) {
    await rcon.run(`${prefix}data modify storage rcontest:utf8 v append value "${element}"`)
  }
  for (let pad = 0; pad < 4; pad++) {
    await rcon.run(`${prefix}data modify storage rcontest:utf8 v[0] set value "${'a'.repeat(pad)}"`)
    const replies = await rcon.run(`${prefix}data get storage rcontest:utf8`)
    const body = Buffer.concat(replies.map((p) => p.body))
    const runs = body.toString('utf8').match(/é+/g) || []
    const intact = runs.filter((run) => run.length === element.length).length
    const broken = runs.length - intact
    const sizes = replies.map((p) => p.size)
    console.log(`utf8 pad=${pad}: packet sizes ${JSON.stringify(sizes)}, ${intact} intact and ${broken} broken elements, ${body.includes(replacement) ? 'has' : 'no'} U+FFFD`)
    if (body.includes(replacement) || broken || !intact) {
      failures.push(`pad=${pad}: a multi-byte character was split across packets (${intact} intact and ${broken} broken elements)`)
    }
    if (patched && sizes.some((size) => size > maxPacketSize)) {
      failures.push(`pad=${pad}: a packet is larger than ${maxPacketSize} bytes: ${JSON.stringify(sizes)}`)
    }
  }
  await rcon.run(`${prefix}data remove storage rcontest:utf8 v`)
  rcon.close()

  for (const failure of failures) console.log(`::error::${failure}`)
  process.exit(failures.length ? 1 : 0)
}

main().catch((error) => {
  console.log(`::error::${error.message}`)
  process.exit(1)
})
