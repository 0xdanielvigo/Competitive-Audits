import hre, { ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

// RUN: BRIDGE_AMOUNT=10 TO_ADDRESS=0x5166ef11e5dF6D4Ca213778fFf4756937e469663 npx hardhat run scripts/quote.ts --network arbitrumOne

async function main() {
    const { deployments } = hre
    console.log(`Network: ${hre.network.name}`)

    // PARAMS
    const BRIDGE_AMOUNT = process.env.BRIDGE_AMOUNT
    const TO_ADDRESS = process.env.TO_ADDRESS
    const GAS_LIMIT = 200000 // Gas limit for the executor
    const MSG_VALUE = 0 // msg.value for the lzReceive() function on destination in wei

    if (!BRIDGE_AMOUNT || !TO_ADDRESS) {
        console.error(
            'Usage: BRIDGE_AMOUNT=<amount> TO_ADDRESS=<address> npx hardhat run scripts/quote.ts --network arbitrumOne'
        )
        process.exit(1)
    }

    // Validate the arguments
    if (!ethers.utils.isAddress(TO_ADDRESS)) {
        console.error('Invalid destination address.')
        process.exit(1)
    }

    // Initialize provider and contract
    const provider = new ethers.providers.JsonRpcProvider('https://arb1.arbitrum.io/rpc')
    const deployment = await deployments.get('Titn')
    const contract = new ethers.Contract(deployment.address, deployment.abi, provider)

    // Test the quoteSend function
    console.log('Testing quoteSend...')
    const dstEid = EndpointId.BASE_V2_MAINNET // Destination endpoint ID
    const to = ethers.utils.hexZeroPad(TO_ADDRESS, 32)
    const amountLD = ethers.utils.parseUnits(BRIDGE_AMOUNT, 18) // 1 token with 18 decimals
    const minAmountLD = ethers.utils.parseUnits(BRIDGE_AMOUNT, 18) // Minimum amount
    const extraOptions = Options.newOptions().addExecutorLzReceiveOption(GAS_LIMIT, MSG_VALUE).toHex()
    const composeMsg = '0x' // Empty bytes
    const oftCmd = '0x' // Empty bytes

    try {
        const result = await contract.quoteSend(
            { dstEid, to, amountLD, minAmountLD, extraOptions, composeMsg, oftCmd },
            false
        )
        const ethToSend = ethers.utils.formatUnits(result.nativeFee.toString(), 18).toString()
        const nativeFee = result.nativeFee.toString()
        console.log('send() params:', {
            send: ethToSend,
            _sendParam: {
                dstEid,
                to,
                amountLD,
                minAmountLD,
                extraOptions,
                composeMsg,
                oftCmd,
            },
            _fee: {
                nativeFee,
                lzTokenFee: 0,
            },
            _refundAddress: TO_ADDRESS,
        })
    } catch (err) {
        console.error('Error calling quoteSend:', err)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
