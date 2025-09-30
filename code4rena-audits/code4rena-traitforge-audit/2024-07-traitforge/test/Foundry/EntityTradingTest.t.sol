// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//run this test --> sudo forge test --match-path test/Foundry/EntityTradingTest.t.sol -vvv --gas-limit 200000000000

import {Test, console} from "forge-std/Test.sol"; 

import {EntityForging} from "../../contracts/EntityForging/EntityForging.sol"; 
import {IEntityForging} from "../../contracts/EntityForging/IEntityForging.sol"; 
import {TraitForgeNft} from "../../contracts/TraitForgeNft/TraitForgeNft.sol"; 
import {ITraitForgeNft} from "../../contracts/TraitForgeNft/ITraitForgeNft.sol"; 
import {Airdrop} from "../../contracts/Airdrop/Airdrop.sol"; 
import {IAirdrop} from "../../contracts/Airdrop/IAirdrop.sol"; 
import {EntropyGenerator} from "../../contracts/EntropyGenerator/EntropyGenerator.sol"; 
import {IEntropyGenerator} from "../../contracts/EntropyGenerator/IEntropyGenerator.sol";
import {EntityTrading} from "../../contracts/EntityTrading/EntityTrading.sol"; 
import {IEntityTrading} from "../../contracts/EntityTrading/IEntityTrading.sol";

contract TraitForgeNftTest is Test {
address public owner; 

TraitForgeNft public traitForgeNft; 

Airdrop public airdropContract; 

EntityForging public entityForging; 

EntropyGenerator public entropyGenerator; 

EntityTrading public entityTrading; 

 struct Listing {
    address seller; // address of NFT seller
    uint256 tokenId; // token id of NFT
    uint256 price; // Price of the NFT in wei
    bool isActive; // flag to check if the listing is active
  }

function setUp() public {
owner = address(this); 
traitForgeNft = new TraitForgeNft(); 
airdropContract = new Airdrop(); 
entityForging = new EntityForging(address(traitForgeNft)); 
entropyGenerator = new EntropyGenerator(address(traitForgeNft)); 
entityTrading = new EntityTrading(address(traitForgeNft));
}

//invariants variable 
function invariant_nftContract() public view {
ITraitForgeNft nftAddress = entityTrading.nftContract(); 
assertEq(address(nftAddress), address(traitForgeNft)); 
}

//setNukeFundAddress
function test_setNukeFundAddressNotTheOwner() public {
vm.startPrank(address(1323)); 
vm.expectRevert(); 
entityTrading.setNukeFundAddress(payable(address(123)));
}

function test_setNukeFundAddressWorks() public {
vm.startPrank(owner); 
entityTrading.setNukeFundAddress(payable(address(123)));
}

//setTaxCut
function test_setTaxCutNotTheOwner() public {
vm.startPrank(address(1323)); 
vm.expectRevert(); 
entityTrading.setTaxCut(100);
}

function test_setTaxCutWorks(uint256 value) public {
vm.startPrank(owner); 
value = bound(value, 0, type(uint256).max); 
entityTrading.setTaxCut(value);
}

//listNFTForSale
function test_listNftForSalePriceIs0() public {
vm.expectRevert('Price must be greater than zero'); 
entityTrading.listNFTForSale(0, 0);
}

function test_listNftForSaleOwnerNotTheSender() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
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
deal(user2, 1 ether); 
vm.expectRevert('Sender must be the NFT owner.');
entityTrading.listNFTForSale(1, 100);
}

function test_listNftForSaleContractNotApproved() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

vm.expectRevert('Contract must be approved to transfer the NFT.');
entityTrading.listNFTForSale(1, 100);
}

function test_listNftForSaleWorks(uint256 price) public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

price = bound(price, 1, user1.balance); 
entityTrading.listNFTForSale(1, price);

assertNotEq(traitForgeNft.ownerOf(1), user1); 
assertEq(traitForgeNft.ownerOf(1), address(entityTrading)); 

assertEq(entityTrading.listingCount(), 1); 
}

//buyNFT
function test_buyNFTETHDoesNotMatch() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

entityTrading.listNFTForSale(1, 0.001 ether);
vm.stopPrank(); 

address user2 = address(124); 
vm.startPrank(user2); 
deal(user2, 1 ether);
vm.expectRevert('ETH sent does not match the listing price'); 
entityTrading.buyNFT{value: 0.0001 ether}(1);
}

function test_buyNFTNFTNotListed() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

uint256 price = 0.001 ether; 
entityTrading.listNFTForSale(1, price);
vm.stopPrank(); 

address user2 = address(124); 
vm.startPrank(user2); 
deal(user2, 1 ether);
vm.expectRevert('NFT is not listed for sale.'); 
entityTrading.buyNFT{value: 0}(2);
}

function test_buyNFTWorks() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
address nukeFund = address(12232121); 
entityTrading.setNukeFundAddress(payable(nukeFund));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

uint256 price = 0.001 ether; 
entityTrading.listNFTForSale(1, price);
vm.stopPrank(); 

address user2 = address(124); 
vm.startPrank(user2); 
deal(user2, 1 ether);
entityTrading.buyNFT{value: price}(1);

assertEq(user1.balance, 1 ether - 0.005 ether + (price * 90) / 100); 
assertNotEq(traitForgeNft.ownerOf(1), address(traitForgeNft)); 
assertNotEq(traitForgeNft.ownerOf(1), user1); 
assertEq(traitForgeNft.ownerOf(1), user2); 
}

//cancelListing
function test_cancelListing_notTheSeller() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
address nukeFund = address(12232121); 
entityTrading.setNukeFundAddress(payable(nukeFund));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

uint256 price = 0.001 ether; 
entityTrading.listNFTForSale(1, price);
vm.stopPrank(); 

address user2 = address(124); 
vm.startPrank(user2); 
vm.expectRevert('Only the seller can canel the listing.'); 
entityTrading.cancelListing(1);
}

function test_cancelListingWorks() public {
vm.startPrank(owner); 
traitForgeNft.setAirdropContract(address(airdropContract));
traitForgeNft.setEntityForgingContract(address(entityForging));
traitForgeNft.setEntropyGenerator(address(entropyGenerator));
airdropContract.transferOwnership(address(traitForgeNft));
address nukeFund = address(12232121); 
entityTrading.setNukeFundAddress(payable(nukeFund));
vm.stopPrank(); 

address user1 = address(123); 
deal(user1, 1 ether); 
vm.startPrank(user1); 
skip(2 days);
bytes32[] memory proof = new bytes32[](1); 
proof[0] = keccak256(abi.encode("Hi")); 
traitForgeNft.mintToken{value: 0.005 ether}(proof);

traitForgeNft.approve(address(entityTrading), 1);

uint256 price = 0.001 ether; 
entityTrading.listNFTForSale(1, price);
vm.stopPrank(); 

vm.startPrank(user1); 
entityTrading.cancelListing(1);

assertEq(traitForgeNft.ownerOf(1), user1); 
assertNotEq(traitForgeNft.ownerOf(1), address(entityTrading)); 

}
}