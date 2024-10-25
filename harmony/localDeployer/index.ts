import  { createPublicClient, createWalletClient, defineChain, Hex, type Address, hexToBigInt, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { ENTRY_POINT_V07_BYTECODE } from './constants'

// NOTE: Harmony's testnet and localnet share the same chain id
// below setup is for localnet use only

// ensure SAFE_SINGLETON_FACTORY is deployed
const SAFE_SINGLETON_FACTORY = "0xa210f356046b9497E73581F0b8B38fa4988F913B"
// for CREATE2 deployment
const salt: Hex = "0x90d8084deab30c2a37c45e8d47f49f2f7965183cb6990a98943ef94940681de3"

const harmonyLocalnet = defineChain({
  id: 1_666_700_000,
  name: "Harmony One",
  nativeCurrency: {
    name: "Harmony",
    symbol: "ONE",
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ["http://localhost:9501"]
    }
  }
})

const publicClient = createPublicClient({
  chain: harmonyLocalnet,
  transport: http("http://localhost:9501")
})

const account = privateKeyToAccount("0x1f84c95ac16e6a50f08d44c7bde7aff8742212fda6e4321fde48bf83bef266dc")
const walletClient = createWalletClient({
  account,
  chain: harmonyLocalnet,
  transport: http("http://localhost:9501")
})

const verifyDeployed = async (addresses: Address[]) => {
  for (const address of addresses) {
      const bytecode = await publicClient.getBytecode({
          address
      })

      if (bytecode === undefined) {
          console.log(`CONTRACT ${address} NOT DEPLOYED!!!`)
          process.exit(1)
      }
  }
}

const main = async () => {

  const txs: Hex[] = []

  // console.log("========== DEPLOYING V0.7 CORE CONTRACTS ==========")

  
  const ENTRY_POINT_CALLDATA = salt as Hex + ENTRY_POINT_V07_BYTECODE.substring(2) as Hex
  
  txs.push(
    await walletClient.sendTransaction({
      to: SAFE_SINGLETON_FACTORY,
      data: ENTRY_POINT_CALLDATA,
      gas: 15_000_000n
    })
  )
  
  console.log("Deployed EntryPoint V0.7")

  // console.log("Deployed SimpleAccountFactory v0.7")

  // console.log("Deployed EntryPointSimulations")

  console.log("Waiting for transactions...")
  for (const hash of txs) {
    await publicClient.waitForTransactionReceipt({ hash })
  }

  console.log("Verifying deployments...")
  await verifyDeployed([
    "0xb1f4d85750469e5bee4f70f028011fb682bf2c1a", // EntryPoint.sol
  ])
  console.log("Done!")
}

main().then(() => process.exit(0))