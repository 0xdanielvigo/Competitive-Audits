// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "../../../lib/forge-std/src/Test.sol"; 

import {ChakraSettlementHandler} from "../../../solidity/handler/contracts/ChakraSettlementHandler.sol"; 

import {BaseSettlementHandler} from "../../../solidity/handler/contracts/BaseSettlementHandler.sol"; 

import {ChakraToken} from "../../../solidity/handler/contracts/ChakraToken.sol"; 

import {ERC20CodecV1} from "../../../solidity/handler/contracts/ERC20CodecV1.sol"; 

import {IERC20CodecV1} from "../../../solidity/handler/contracts/interfaces/IERC20CodecV1.sol"; 

import {ChakraSettlement} from "../../../solidity/settlement/contracts/ChakraSettlement.sol";

import {SettlementSignatureVerifier} from "../../../solidity/handler/contracts/SettlementSignatureVerifier.sol";

import {ISettlementSignatureVerifier} from "../../../solidity/handler/contracts/interfaces/ISettlementSignatureVerifier.sol";

import {ISettlement} from "../../../solidity/handler/contracts/interfaces/ISettlement.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { PayloadType, CrossChainMsgStatus } from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {ERC20TransferPayload} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {ERC20Method} from "../../../solidity/handler/contracts/libraries/ERC20Payload.sol";

import {AddressCast} from "../../../solidity/handler/contracts/libraries/AddressCast.sol";

import {Message} from "../../../solidity/settlement/contracts/libraries/Message.sol";

import {MessageV1Codec} from "../../../solidity/settlement/contracts/libraries/MessageV1Codec.sol";

contract GeneralTestBurnUnlockNotUsingChakraToken is Test{

    uint256 ethFork; 
    uint256 arbFork;
    uint256 baseFork; 

//ARB
ChakraSettlementHandler public chakraSettlementHandlerArb; 

address public LINK_arb = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4; 

ERC20CodecV1 public codecArb; 

ChakraSettlement public chakraSettlementArb; 

SettlementSignatureVerifier public settlementSignatureVerifierArb; 

//ETH
ChakraSettlementHandler public chakraSettlementHandlerEth; 

address public LINK_eth = 0x514910771AF9Ca656af840dff83E8264EcF986CA; 

address public WETH_eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; 

ERC20CodecV1 public codecEth; 

ChakraSettlement public chakraSettlementEth; 

SettlementSignatureVerifier public settlementSignatureVerifierEth; 


address public bob = makeAddr("bob");
address public tob = makeAddr("tob");

address public owner; 
   
function setUp() public {
initializeOnArbitrum();
initializeOnEthereum();
}

function initializeOnArbitrum() public {
arbFork = vm.createFork("use your own rpc url");
vm.selectFork(arbFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierArb = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierArb.initialize(address(this), 1);

//codec
codecArb = new ERC20CodecV1(); 
//codec initialized
codecArb.initialize(address(this));

//chakraSettlement
chakraSettlementArb = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementArb.initialize("Abitrum", 137, owner, managers, 1, address(settlementSignatureVerifierArb));

//chakraSettlementHandler
chakraSettlementHandlerArb = new ChakraSettlementHandler();
chakraSettlementHandlerArb.initialize(owner, BaseSettlementHandler.SettlementMode.BurnUnlock, "Arbitrum", address(LINK_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

}

function initializeOnEthereum() public {
ethFork = vm.createFork("use your own rpc url");
vm.selectFork(ethFork);
owner = address(this); 

//settlementSignatureVerifier 
settlementSignatureVerifierEth = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierEth.initialize(address(this), 1);

//codec
codecEth = new ERC20CodecV1(); 
//codec initialized
codecEth.initialize(address(this));

//chakraSettlement
chakraSettlementEth = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementEth.initialize("Ethereum", 1, owner, managers, 1, address(settlementSignatureVerifierEth));

//chakraSettlementHandler
chakraSettlementHandlerEth = new ChakraSettlementHandler();
chakraSettlementHandlerEth.initialize(owner, BaseSettlementHandler.SettlementMode.BurnUnlock, "Ethereum", address(WETH_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));
}


//@audit high, Every ERC20 token could be accepted and used in this protocol, but all the tokens (Such as LINK, UNI, DAI etc) that has not the 'ChakraToken' design, 
//do not implements the functions 'mint_to' and 'burn_from', so these tokens can't be used in the following modes: MintBurn, LockMint, BurnUnlock
function test_SomeERC20CantBeUsedInSomeModalities() public {
//Note: the required validators is setted to 1, all the contracts have been initializated and the mode is setted to BurnUnlock.
uint256 privateKeyValidator1 = 0x12D; 
address validator1 = vm.addr(privateKeyValidator1);

address UserAccount1 = makeAddr("UserAccount1");

//Here owner Adds managers to both chains (arbitrum and ethereum)
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_manager(bob);
vm.stopPrank(); 

//Here owner Adds validators to both chains (arbitrum and ethereum)
vm.startPrank(bob);
vm.selectFork(arbFork);
settlementSignatureVerifierArb.add_validator(validator1);
vm.selectFork(ethFork);
settlementSignatureVerifierEth.add_validator(validator1);
vm.stopPrank();

//Here owner adds valid handler on ethereum
vm.selectFork(ethFork);
vm.startPrank(owner); 
chakraSettlementHandlerEth.add_handler("Arbitrum", uint160(address(chakraSettlementHandlerArb)));
vm.stopPrank();

vm.startPrank(UserAccount1);
vm.selectFork(arbFork);

//Give 100 chakra token to user on arbitrum
deal(address(LINK_arb), UserAccount1, 100e18); 
//Approve the handler 
IERC20(address(LINK_arb)).approve(address(chakraSettlementHandlerArb), 100e18);

//This call will fail since LINK in this case, does not implement a 'burn_from' function.
vm.expectRevert(); 
chakraSettlementHandlerArb.cross_chain_erc20_settlement("Ethereum", uint160(address(chakraSettlementHandlerEth)), uint160(address(LINK_eth)), uint160(UserAccount1), 100e18);
vm.stopPrank();

}
}