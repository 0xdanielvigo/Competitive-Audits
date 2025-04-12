import hre from 'hardhat'

// RUN: npx hardhat run scripts/arbitrumSetup.ts --network arbitrumOne

async function main() {
    const { deployments, ethers } = hre
    const [signer] = await ethers.getSigners()
    console.log(`Network: ${hre.network.name}`)

    // PARAMS
    const TITN_DEPOSIT_AMOUNT = '173700000000000000000000000' // this amount will be depoisted on the mergeTgt contract

    // Initialize contract
    const deploymentTitn = await deployments.get('Titn')
    const titn = new ethers.Contract(deploymentTitn.address, deploymentTitn.abi, signer)
    const deploymentMergeTgt = await deployments.get('MergeTgt')
    const mergeTgt = new ethers.Contract(deploymentMergeTgt.address, deploymentMergeTgt.abi, signer)

    try {
        console.log(`Initialting Arbitrum setup steps:`)
        await titn.setTransferAllowedContract(deploymentMergeTgt.address)
        console.log(`1/5 titn.setTransferAllowedContract(address) ✅`)
        await mergeTgt.setLaunchTime()
        console.log(`2/5 mergeTgt.setLaunchTime() ✅`)
        await mergeTgt.setLockedStatus(1)
        console.log(`3/5 mergeTgt.setLockedStatus(1) ✅`)
        await titn.approve(deploymentMergeTgt.address, TITN_DEPOSIT_AMOUNT)
        console.log(`4/5 titn.approve(mergeTgt, 173.7m TITN) ✅`)
        await mergeTgt.deposit(deploymentTitn.address, TITN_DEPOSIT_AMOUNT)
        console.log(`5/5 mergeTgt.deposit(titn, 173.7m) ✅`)

        console.log(`Arbitrum setup steps completed`)
    } catch (err) {
        console.error('Arbitrum setup steps failed 🛑', err)
    }
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
