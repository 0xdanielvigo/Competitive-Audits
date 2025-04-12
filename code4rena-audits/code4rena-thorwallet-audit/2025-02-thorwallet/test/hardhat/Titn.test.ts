import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'

describe('Titn tests', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Other variables to be used in the test suite
    let Titn: ContractFactory
    let EndpointV2Mock: ContractFactory
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let user1: SignerWithAddress
    let user2: SignerWithAddress
    let baseTITN: Contract
    let arbTITN: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract
    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        Titn = await ethers.getContractFactory('Titn')
        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()
        ;[ownerA, ownerB, endpointOwner, user1, user2] = signers
        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    beforeEach(async function () {
        // Deploying a mock LZEndpoint with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)
        // Deploying two instances of the TITN contract with different identifiers and linking them to the mock LZEndpoint
        baseTITN = await Titn.deploy(
            'baseTitn',
            'baseTITN',
            mockEndpointV2A.address,
            ownerA.address,
            ethers.utils.parseUnits('1000000000', 18)
        )
        arbTITN = await Titn.deploy(
            'arbTitn',
            'arbTITN',
            mockEndpointV2B.address,
            ownerB.address,
            ethers.utils.parseUnits('0', 18)
        )
        // Setting destination endpoints in the LZEndpoint mock for each TITN instance
        await mockEndpointV2A.setDestLzEndpoint(arbTITN.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(baseTITN.address, mockEndpointV2A.address)
        // Setting each TITN instance as a peer of the other in the mock LZEndpoint
        await baseTITN.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(arbTITN.address, 32))
        await arbTITN.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(baseTITN.address, 32))
    })

    it('should send a token from A address to B address via each OFT', async function () {
        // Minting an initial amount of tokens to ownerA's address in the TITN contract
        const initialAmount = ethers.utils.parseEther('1000000000')
        // Defining the amount of tokens to send and constructing the parameters for the send operation
        const tokensToSend = ethers.utils.parseEther('1')
        // Defining extra message execution options for the send operation
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
        const sendParam = [
            eidB,
            ethers.utils.zeroPad(ownerB.address, 32),
            tokensToSend,
            tokensToSend,
            options,
            '0x',
            '0x',
        ]
        // Fetching the native fee for the token send operation
        const [nativeFee] = await baseTITN.quoteSend(sendParam, false)
        // Executing the send operation from TITN contract
        await baseTITN.send(sendParam, [nativeFee, 0], ownerA.address, { value: nativeFee })
        // Fetching the final token balances of ownerA and ownerB
        const finalBalanceA = await baseTITN.balanceOf(ownerA.address)
        const finalBalanceB = await arbTITN.balanceOf(ownerB.address)
        // Asserting that the final balances are as expected after the send operation
        expect(finalBalanceA).eql(initialAmount.sub(tokensToSend))
        expect(finalBalanceB).eql(tokensToSend)
    })
    it('should bridge tokens back from ARB to BASE', async function () {
        const tokensToSend = ethers.utils.parseEther('1')
        // Defining extra message execution options for the send operation
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
        const sendParam = [
            eidB,
            ethers.utils.zeroPad(ownerB.address, 32),
            tokensToSend,
            tokensToSend,
            options,
            '0x',
            '0x',
        ]
        // Fetching the native fee for the token send operation
        const [nativeFee] = await baseTITN.quoteSend(sendParam, false)
        // Executing the send operation from TITN contract
        await baseTITN.send(sendParam, [nativeFee, 0], ownerA.address, { value: nativeFee })

        // Fetch ownerB's initial balance on arbTITN
        const initialBalanceB = await arbTITN.balanceOf(ownerB.address)
        expect(initialBalanceB).to.eql(ethers.utils.parseEther('1')) // Confirm ownerB has 1 TITN on arbTITN

        // Define the amount to send back and construct the parameters for the send operation
        const tokensToSendBack = ethers.utils.parseEther('1') // Sending back the entire balance
        const optionsBack = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
        const sendBackParam = [
            eidA, // Base endpoint ID
            ethers.utils.zeroPad(ownerB.address, 32), // Sending back to ownerA's address on Base
            tokensToSendBack, // Amount to send
            tokensToSendBack, // Minimum amount to send
            optionsBack, // Additional execution options
            '0x', // Call data (none in this case)
            '0x', // Call data (none in this case)
        ]

        // // Fetch the native fee for bridging the tokens back
        const [nativeFeeBack] = await arbTITN.quoteSend(sendBackParam, false)

        // // Execute the bridging operation from arbTITN to baseTITN
        await arbTITN.connect(ownerB).send(sendBackParam, [nativeFeeBack, 0], ownerB.address, { value: nativeFeeBack })

        // // Fetch final balances on arbTITN and baseTITN
        const finalBalanceB = await arbTITN.balanceOf(ownerB.address)
        const finalBalanceBOnBase = await baseTITN.balanceOf(ownerB.address)

        // Assert balances after the bridging operation
        expect(finalBalanceB).to.eql(ethers.utils.parseEther('0')) // ownerB should have no tokens left on arbTITN
        expect(finalBalanceBOnBase.toString()).to.eql(tokensToSendBack.toString()) // ownerA should receive 1 TITN back on baseTITN
    })
})
