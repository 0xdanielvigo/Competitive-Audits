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

contract ChakraSettlementHandlerTest is Test{

    uint256 ethFork; 
    uint256 arbFork;

//ARB
ChakraSettlementHandler public chakraSettlementHandlerArb; 

ChakraToken public chakraTokenArb;

ERC20CodecV1 public codecArb; 

ChakraSettlement public chakraSettlementArb; 

SettlementSignatureVerifier public settlementSignatureVerifierArb; 

//ETH
ChakraSettlementHandler public chakraSettlementHandlerEth; 

ChakraToken public chakraTokenEth;

ERC20CodecV1 public codecEth; 

ChakraSettlement public chakraSettlementEth; 

SettlementSignatureVerifier public settlementSignatureVerifierEth; 

ChakraToken chakraToken_arb; 
ChakraToken chakraToken_eth;  

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

//chakraToken
chakraToken_arb = new ChakraToken(); 
//chakraToken initialized
chakraToken_arb.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

//codec
codecArb = new ERC20CodecV1(); 
//codec initialized
codecArb.initialize(address(this));

//chakraSettlement
chakraSettlementArb = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = address(231); 
managers[1] = address(3141); 
chakraSettlementArb.initialize("Abitrum", 137, address(this), managers, 1, address(settlementSignatureVerifierArb));

//chakraSettlementHandler
chakraSettlementHandlerArb = new ChakraSettlementHandler();
chakraSettlementHandlerArb.initialize(address(this), BaseSettlementHandler.SettlementMode.MintBurn, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));

//add validator in chakra token
chakraToken_arb.add_operator(address(chakraSettlementHandlerArb));
}

function initializeOnEthereum() public {
ethFork = vm.createFork("use your own rpc url");
vm.selectFork(ethFork);
owner = address(this); 
//chakraSettlement
chakraSettlementEth = new ChakraSettlement();

//settlementSignatureVerifier 
settlementSignatureVerifierEth = new SettlementSignatureVerifier(); 
//settlementSignatureVerifier initialized
settlementSignatureVerifierEth.initialize(address(this), 1);

//chakraToken
chakraToken_eth = new ChakraToken(); 
//chakraToken initialized
chakraToken_eth.initialize(address(this), address(this), "ChakraToken", "CKT", 18);

//codec
codecEth = new ERC20CodecV1(); 
//codec initialized
codecEth.initialize(address(this));

//chakraSettlementHandler
chakraSettlementHandlerEth = new ChakraSettlementHandler();
chakraSettlementHandlerEth.initialize(address(this), BaseSettlementHandler.SettlementMode.MintBurn, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));

//add validator in chakra token
chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
}


function test_settlementHandlerCantBeInitializedTwice_arb() public {
vm.selectFork(arbFork);
vm.expectRevert(); 
chakraSettlementHandlerArb.initialize(address(this), BaseSettlementHandler.SettlementMode.MintBurn, "Arbitrum", address(chakraToken_arb), address(codecArb), address(settlementSignatureVerifierArb), address(chakraSettlementArb));
}

// add / remove handler and onlyOwner 
function test_addAndRemoveHandler_arb() public {
vm.selectFork(arbFork);
vm.startPrank(owner); 
chakraSettlementHandlerArb.add_handler("BSC", 10);
assertEq(chakraSettlementHandlerArb.handler_whitelist("BSC", 10), true); 
assertEq(chakraSettlementHandlerArb.is_valid_handler("BSC", 10), true);
chakraSettlementHandlerArb.remove_handler("BSC", 10);
assertEq(chakraSettlementHandlerArb.handler_whitelist("BSC", 10), false); 
assertEq(chakraSettlementHandlerArb.is_valid_handler("BSC", 10), false);
vm.stopPrank(); 

address casualAddr = address(123); 
vm.startPrank(casualAddr); 
vm.expectRevert(); 
chakraSettlementHandlerArb.add_handler("BSC", 10);
}

//send cross chain tx
function test_sendCrossChainTx() public {
vm.selectFork(arbFork);
address marco = address(123); 
deal(address(chakraToken_arb), marco, 100e18); 
address paul = address(124); 
vm.startPrank(marco); 
IERC20(chakraToken_arb).approve(address(chakraSettlementHandlerArb), 10e18);
chakraSettlementHandlerArb.cross_chain_erc20_settlement("Ethereum", uint160(address(chakraSettlementEth)), uint160(address(chakraToken_arb)), uint160(address(paul)), 10e18);
assertEq(IERC20(chakraToken_arb).balanceOf(marco), 100e18 - 10e18); 
assertEq(IERC20(chakraToken_arb).balanceOf(address(chakraSettlementHandlerArb)), 10e18); 
assertEq(chakraSettlementHandlerArb.nonce_manager(marco), 1); 
assertEq(chakraSettlementHandlerArb.cross_chain_msg_id_counter(), 1); 
}

}
