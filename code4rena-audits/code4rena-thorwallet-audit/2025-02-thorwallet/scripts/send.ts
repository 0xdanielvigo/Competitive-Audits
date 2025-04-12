import hre from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

// RUN: npx hardhat run scripts/send.ts --network arbitrumOne

async function main() {
    const { deployments, ethers } = hre
    const [signer] = await ethers.getSigners()
    console.log(`Network: ${hre.network.name}`)

    // PARAMS
    const BRIDGE_AMOUNT = '1876'
    const TO_ADDRESS = '0x58430df70e23405fb8d8ab8c854e1f70696d636e'
    const GAS_LIMIT = 200000 // Gas limit for the executor
    const MSG_VALUE = 0 // msg.value for the lzReceive() function on destination in wei

    // Initialize contract
    const deployment = await deployments.get('Titn')
    const contract = new ethers.Contract(deployment.address, deployment.abi, signer)

    // quoteSend and send function params
    const dstEid = EndpointId.BASE_V2_MAINNET // Destination endpoint ID
    const to = ethers.utils.hexZeroPad(TO_ADDRESS, 32)
    const amountLD = ethers.utils.parseUnits(BRIDGE_AMOUNT, 18) // 1 token with 18 decimals
    const minAmountLD = ethers.utils.parseUnits(BRIDGE_AMOUNT, 18) // Minimum amount
    const extraOptions = Options.newOptions().addExecutorLzReceiveOption(GAS_LIMIT, MSG_VALUE).toHex()
    const composeMsg = '0x' // Empty bytes
    const oftCmd = '0x' // Empty bytes

    try {
        // we first need to get a quote so that we know what the fees are
        const quote = await contract.quoteSend(
            { dstEid, to, amountLD, minAmountLD, extraOptions, composeMsg, oftCmd },
            false
        )
        const nativeFee = quote.nativeFee.toString()

        // now we can call the send function
        const result = await contract.send(
            {
                dstEid,
                to,
                amountLD,
                minAmountLD,
                extraOptions,
                composeMsg,
                oftCmd,
            },
            {
                nativeFee,
                lzTokenFee: 0,
            },
            TO_ADDRESS,
            { value: nativeFee, gasLimit: 1000000 }
        )
        console.log(`Bridged ${BRIDGE_AMOUNT} TITN tokens to BASE. Hash ${result.hash}`)
        console.log(`Follow: https://layerzeroscan.com/tx/${result.hash}`)
    } catch (err) {
        console.error('Error calling send:', err)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
