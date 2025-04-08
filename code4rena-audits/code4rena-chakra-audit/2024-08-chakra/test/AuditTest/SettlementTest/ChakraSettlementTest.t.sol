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

import {PayloadType, CrossChainMsgStatus} from "../../../solidity/settlement/contracts/libraries/Message.sol";

contract ChakraSettlementTest is Test{

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

address public bob = makeAddr("bob");
address public tob = makeAddr("tob");
   
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
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementArb.initialize("Arbitrum", 137, owner, managers, 1, address(settlementSignatureVerifierArb));

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

//chakraSettlement
chakraSettlementEth = new ChakraSettlement();
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementEth.initialize("Ethereum", 1, owner, managers, 1, address(settlementSignatureVerifierEth));

//chakraSettlementHandler
chakraSettlementHandlerEth = new ChakraSettlementHandler();
chakraSettlementHandlerEth.initialize(address(this), BaseSettlementHandler.SettlementMode.MintBurn, "Ethereum", address(chakraToken_eth), address(codecEth), address(settlementSignatureVerifierEth), address(chakraSettlementEth));

//add validator in chakra token
chakraToken_eth.add_operator(address(chakraSettlementHandlerEth));
}

//initial variables
function test_initialVariables() public {
vm.startPrank(owner); 
vm.selectFork(arbFork);
assertEq(chakraSettlementArb.chain_id(), 137); 
assertEq(chakraSettlementArb.contract_chain_name(), "Arbitrum"); 
assertEq(chakraSettlementArb.required_validators(), 1); 
assertEq(chakraSettlementArb.validator_count(), 0); 
}

//cant initialize again
function test_cantInitializeAgin() public {
vm.startPrank(owner); 
vm.selectFork(arbFork);
vm.expectRevert(); 
address[] memory managers = new address[](2); 
managers[0] = bob; 
managers[1] = tob; 
chakraSettlementArb._Settlement_init("Arbitrum",137, owner, managers, 1, address(settlementSignatureVerifierArb));
}

//add manager / remove manager / is manager
function test_managers() public {
vm.startPrank(owner); 
vm.selectFork(arbFork);
address pino = makeAddr("pino");
chakraSettlementArb.add_manager(pino);
assertEq(chakraSettlementArb.is_manager(pino), true);
chakraSettlementArb.remove_manager(pino);
assertEq(chakraSettlementArb.is_manager(pino),false);
}

//add validator / remove validator / is validator /set required num of validators
function test_validators() public {
vm.selectFork(arbFork);
    vm.startPrank(owner);
    settlementSignatureVerifierArb.add_manager(bob);
    settlementSignatureVerifierArb.add_manager(address(chakraSettlementArb));
    assertEq(settlementSignatureVerifierArb.is_manager(bob), true);
    vm.stopPrank();
vm.startPrank(bob); 
address luca = makeAddr("luca");
chakraSettlementArb.add_validator(luca);
assertEq(chakraSettlementArb.is_validator(luca), true);
assertEq(chakraSettlementArb.validator_count(), 1);
chakraSettlementArb.remove_validator(luca);
assertEq(chakraSettlementArb.is_validator(luca), false);
assertEq(chakraSettlementArb.validator_count(), 0);
chakraSettlementArb.set_required_validators_num(10);
assertEq(chakraSettlementArb.required_validators(), 10); 
}

//verify 
function test_verifySignature() public {
vm.selectFork(arbFork);
vm.startPrank(owner);
settlementSignatureVerifierArb.add_manager(bob);
vm.stopPrank();
vm.startPrank(bob);
uint256 privateKey = 0x12D; 
address validator1 = vm.addr(privateKey);
settlementSignatureVerifierArb.add_validator(validator1);
vm.stopPrank(); 
vm.startPrank(validator1); 
bytes32 message = keccak256(abi.encodePacked("Test Message"));
(uint8 v,bytes32 r, bytes32 s) = vm.sign(privateKey, message);
bytes memory signature = abi.encodePacked(r, s, v);
settlementSignatureVerifierArb.verify(message, signature, 0);
}

}