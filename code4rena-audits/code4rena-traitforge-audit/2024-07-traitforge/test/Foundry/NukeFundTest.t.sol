// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//run this test --> sudo forge test --match-path test/Foundry/NukeFundTest.t.sol -vvv --gas-limit 200000000000

import {Test, console} from "forge-std/Test.sol"; 

import {EntityForging} from "../../contracts/EntityForging/EntityForging.sol"; 
import {IEntityForging} from "../../contracts/EntityForging/IEntityForging.sol"; 
import {TraitForgeNft} from "../../contracts/TraitForgeNft/TraitForgeNft.sol"; 
import {ITraitForgeNft} from "../../contracts/TraitForgeNft/ITraitForgeNft.sol"; 
import {Airdrop} from "../../contracts/Airdrop/Airdrop.sol"; 
import {IAirdrop} from "../../contracts/Airdrop/IAirdrop.sol"; 
import {EntropyGenerator} from "../../contracts/EntropyGenerator/EntropyGenerator.sol"; 
import {IEntropyGenerator} from "../../contracts/EntropyGenerator/IEntropyGenerator.sol";
import {NukeFund} from "../../contracts/NukeFund/NukeFund.sol"; 
import {INukeFund} from "../../contracts/NukeFund/INukeFund.sol"; 
import {DevFund} from "../../contracts/DevFund/DevFund.sol"; 
import {IDevFund} from "../../contracts/DevFund/IDevFund.sol"; 
import {DAOFund} from "../../contracts/DAOFund/DAOFund.sol"; 
import {IDAOFund} from "../../contracts/DAOFund/IDAOFund.sol"; 

contract NukeFundTest is Test {
address public owner; 

TraitForgeNft public traitForgeNft; 

Airdrop public airdropContract; 

EntityForging public entityForging; 

EntropyGenerator public entropyGenerator; 

DevFund public devFund; 

DAOFund public daoFund; 

NukeFund public nukeFund;

receive() external payable {} 
fallback() external payable {}


function setUp() public {
owner = address(this); 
traitForgeNft = new TraitForgeNft(); 
airdropContract = new Airdrop(); 
entityForging = new EntityForging(address(traitForgeNft)); 
entropyGenerator = new EntropyGenerator(address(traitForgeNft)); 
devFund = new DevFund(); 
daoFund = new DAOFund(address(123), address(123)); 
nukeFund = new NukeFund(address(traitForgeNft), address(airdropContract), payable(address(devFund)), payable(address(daoFund))); 
}

//invariant variables
function invariant_MAX_DENOMINATOR() public view{
assertEq(nukeFund.MAX_DENOMINATOR(), 100000); 
}

//trigger receive
function test_triggerReceiveWorks() public {
deal(owner, 0 ether); 
address user1 = address(123); 
vm.startPrank(user1); 
deal(user1, 1 ether); 

(bool success, ) = payable(address(nukeFund)).call{value: 0.001 ether}(""); 
require(success); 

assertEq(user1.balance, 1 ether - 0.001 ether); 
assertEq(address(nukeFund).balance, (90 * 0.001 ether)/ 100); 
assertEq(owner.balance, (10 * 0.001 ether)/ 100);
assertEq(nukeFund.getFundBalance(), (90 * 0.001 ether)/ 100); 
}

//calculateAge
function test_calculateAge() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
uint256 priceIncrease = 0.0000245 ether; 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + priceIncrease}(proof);

skip(10 days ); 
// uint256 getAge = nukeFund.calculateAge(1);
// uint256 getAge2 = nukeFund.calculateAge(2);
// console.log(getAge); 
// console.log(getAge2); 
}

//calculateNukeFactor
function test_calculateNukeFactor() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
uint256 priceIncrease = 0.0000245 ether; 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + priceIncrease}(proof);

skip(10 days ); 
// uint256 getNukeFactor = nukeFund.calculateNukeFactor(1);
// uint256 getNukeFactor2 = nukeFund.calculateNukeFactor(1);
// assertEq(getNukeFactor, 0); 
// assertEq(getNukeFactor2, 0); 
}

//canTokenBeNuked
function test_canTokenBeNuked() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
uint256 priceIncrease = 0.0000245 ether; 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + priceIncrease}(proof);

skip(2 days); 
bool _canBeNuked1 = nukeFund.canTokenBeNuked(1);
bool _canBeNuked2 = nukeFund.canTokenBeNuked(2);
assertEq(_canBeNuked1, false); 
assertEq(_canBeNuked2, false); 

skip(2 days); 
bool canBeNuked1 = nukeFund.canTokenBeNuked(1);
bool canBeNuked2 = nukeFund.canTokenBeNuked(2);
assertEq(canBeNuked1, true); 
assertEq(canBeNuked2, true); 
}

//nuke
function test_nuke_invalidTokenId() public {
vm.expectRevert("ERC721: invalid token ID"); 
nukeFund.nuke(1);
}

function test_nuke_notTheOwner() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
vm.stopPrank();

address user2 = address(124); 
vm.startPrank(user2); 
vm.expectRevert('ERC721: caller is not token owner or approved'); 
nukeFund.nuke(1);
}



}