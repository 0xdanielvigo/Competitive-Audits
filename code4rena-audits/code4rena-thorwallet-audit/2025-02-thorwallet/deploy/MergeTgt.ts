import assert from 'assert'
import { type DeployFunction } from 'hardhat-deploy/types'

// RUN: npx hardhat lz:deploy

const contractName = 'MergeTgt'

const deploy: DeployFunction = async (hre) => {
    // We only need to deploy this contract on Arbitrum
    if (hre.network.name !== 'arbitrumOne') return

    const { getNamedAccounts, deployments, run } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const deployment = await deployments.get('Titn')
    // PARAMS
    const TGT_ADDRESS = '0x429fed88f10285e61b12bdf00848315fbdfcc341'
    const TITN_ADDRESS = deployment.address

    const args = [TGT_ADDRESS, TITN_ADDRESS, deployer]
    const { address } = await deploy(contractName, {
        from: deployer,
        args,
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
    try {
        console.log(`Verifying contract...`)
        await run('verify:verify', {
            address,
            constructorArguments: args,
            contract: 'contracts/MergeTgt.sol:MergeTgt',
        })
        console.log(`Verified contract at ${address} ✅`)
    } catch (err) {
        console.error(`Verification failed 🛑:`, err)
    }
}

deploy.tags = [contractName]

export default deploy
