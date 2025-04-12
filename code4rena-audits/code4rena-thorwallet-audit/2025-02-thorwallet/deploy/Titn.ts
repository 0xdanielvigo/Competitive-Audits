import assert from 'assert'
import { type DeployFunction } from 'hardhat-deploy/types'

// RUN: npx hardhat lz:deploy

const contractName = 'Titn'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments, run } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const endpointV2Deployment = await hre.deployments.get('EndpointV2')
    const initialMintAmount =
        hre.network.name === 'arbitrumOne'
            ? hre.ethers.utils.parseUnits('0', 18)
            : hre.ethers.utils.parseUnits('1000000000', 18) // base
    const args = [
        'Titn', // name
        'TITN', // symbol
        endpointV2Deployment.address, // LayerZero's EndpointV2 address
        deployer, // owner
        initialMintAmount,
    ]
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
            contract: 'contracts/Titn.sol:Titn',
        })
        console.log(`Verified contract at ${address} ✅`)
    } catch (err) {
        console.error(`Verification failed 🛑:`, err)
    }
}

deploy.tags = [contractName]

export default deploy
